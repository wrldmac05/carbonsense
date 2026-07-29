import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { image } = await req.json();
    if (!image) throw new Error("No image provided");

    const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");

    // 1. Update the prompt to ask for ingredients
    const prompt = `Analyze this food image. 

Identify the primary ingredients visible or typically present in this dish and return them as an array of strings.

Analyze the food and map it to these categories:
- "Pescatarian Meal (Fish & Rice)" | factor_id: "31c0f8ec-7b07-416a-8ce1-5212647e6dac" | CO2: 1.6
- "Plant-based / Gulay Meal" | factor_id: "32bd37ee-f879-4c69-b769-b762c506ed65" | CO2: 0.8
- "Heavy Beef Meal (e.g., Bulalo/Steak)" | factor_id: "81c7fcff-6015-4922-a4e9-258d53be33b1" | CO2: 6.5
- "Standard Filipino Meal (Pork/Chicken & Rice)" | factor_id: "ba3a3e12-29b8-4c06-b9f8-4756609c538d" | CO2: 2.5

For "is_meatless": return true if the meal contains no meat, poultry, or seafood. Otherwise false.`;

    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${GEMINI_API_KEY}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [
            {
              parts: [
                { text: prompt },
                { inline_data: { mime_type: "image/jpeg", data: image } },
              ],
            },
          ],
          // 2. Update the schema in your fetch call
          generationConfig: {
            response_mime_type: "application/json",
            response_schema: {
              type: "OBJECT",
              properties: {
                food_name: { type: "STRING" },
                db_category: { type: "STRING" },
                factor_id: { type: "STRING" },
                weight_g: { type: "NUMBER" },
                estimated_co2e: { type: "NUMBER" },
                is_meatless: { type: "BOOLEAN" },
                // 👇 NEW: Added ingredients array
                ingredients: {
                  type: "ARRAY",
                  items: { type: "STRING" },
                  description: "List of key identified ingredients",
                },
              },
              required: [
                "food_name",
                "db_category",
                "factor_id",
                "weight_g",
                "estimated_co2e",
                "is_meatless",
                "ingredients", // 👇 NEW: Make it required
              ],
            },
          },
        }),
      },
    );

    const geminiData = await response.json();

    // 🌟 FIX 2: Safely handle Gemini errors before parsing
    if (!geminiData.candidates || geminiData.candidates.length === 0) {
      console.error("Gemini API Error Payload:", JSON.stringify(geminiData));

      // Check for specific Gemini API errors to send back to Flutter
      if (geminiData.error) {
        throw new Error(`Gemini Error: ${geminiData.error.message}`);
      } else if (geminiData.promptFeedback?.blockReason) {
        throw new Error(
          `Image blocked by safety filters: ${geminiData.promptFeedback.blockReason}`,
        );
      } else {
        throw new Error("Gemini returned an invalid response.");
      }
    }

    const rawText = geminiData.candidates[0].content.parts[0].text;
    const cleanJson = rawText.replace(/```json/g, "").replace(/```/g, "")
      .trim();

    return new Response(cleanJson, {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("Function Error:", error);
    const errorMessage = error instanceof Error ? error.message : String(error);
    return new Response(JSON.stringify({ error: errorMessage }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 400,
    });
  }
});
