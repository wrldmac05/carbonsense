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

    // 🌟 UPGRADE: We now feed Gemini the exact factor_id UUIDs!
    const prompt = `Analyze this food image. 
    1. Identify the specific dish name.
    2. Estimate its weight in grams.
    3. Classify the dish into EXACTLY ONE of these database categories and return its exact factor_id and CO2 Factor:
       - "Pescatarian Meal (Fish & Rice)" | factor_id: "31c0f8ec-7b07-416a-8ce1-5212647e6dac" | CO2: 1.6
       - "Plant-based / Gulay Meal" | factor_id: "32bd37ee-f879-4c69-b769-b762c506ed65" | CO2: 0.8
       - "Heavy Beef Meal (e.g., Bulalo/Steak)" | factor_id: "81c7fcff-6015-4922-a4e9-258d53be33b1" | CO2: 6.5
       - "Standard Filipino Meal (Pork/Chicken & Rice)" | factor_id: "ba3a3e12-29b8-4c06-b9f8-4756609c538d" | CO2: 2.5
    4. Set the estimated_co2e to match the CO2 factor you selected.`;

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
          generationConfig: {
            response_mime_type: "application/json",
            response_schema: {
              type: "OBJECT",
              properties: {
                food_name: { type: "STRING" },
                db_category: { type: "STRING" },
                factor_id: { type: "STRING" }, // 🌟 NEW: Force Gemini to return the UUID
                weight_g: { type: "NUMBER" },
                estimated_co2e: { type: "NUMBER" },
              },
              // Make factor_id strictly required
              required: [
                "food_name",
                "db_category",
                "factor_id",
                "weight_g",
                "estimated_co2e",
              ],
            },
          },
        }),
      },
    );

    const geminiData = await response.json();
    const rawText = geminiData.candidates[0].content.parts[0].text;
    const cleanJson = rawText.replace(/```json/g, "").replace(/```/g, "")
      .trim();

    return new Response(cleanJson, {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    return new Response(JSON.stringify({ error: errorMessage }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 400,
    });
  }
});
