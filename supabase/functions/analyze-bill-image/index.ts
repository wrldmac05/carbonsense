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

    // Smart MIME Type Detection (Screenshots are usually PNGs!)
    let detectedMimeType = "image/jpeg";
    if (image.startsWith("iVBORw")) detectedMimeType = "image/png";
    else if (image.startsWith("UklGR")) detectedMimeType = "image/webp";
    else if (image.startsWith("JVBERi")) detectedMimeType = "application/pdf";

    // Constants for Grid Electricity
    const PHILIPPINE_GRID_FACTOR = 0.7120;
    const GRID_FACTOR_ID = "184fdcea-17b3-4370-8dd6-ed33612015c6";

    // Simplified prompt because response_schema does the heavy lifting!
    const prompt = `Analyze this electricity bill image. 
    1. Look for the field labeled "actual consumption" or "kWh" to find the total kilowatt-hours consumed for the current billing period.
    2. Set "kwh_used" to this extracted number.
    3. Set "factor_id" strictly to "${GRID_FACTOR_ID}".
    4. Set "estimated_co2e" to the exact result of (kwh_used * ${PHILIPPINE_GRID_FACTOR}).`;

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
                // 👇 Using the exact snake_case syntax from your working code
                { inline_data: { mime_type: detectedMimeType, data: image } },
              ],
            },
          ],
          generationConfig: {
            response_mime_type: "application/json",
            response_schema: {
              type: "OBJECT",
              properties: {
                kwh_used: { type: "NUMBER" },
                estimated_co2e: { type: "NUMBER" },
                factor_id: { type: "STRING" },
              },
              // Strictly enforce the return keys
              required: [
                "kwh_used",
                "estimated_co2e",
                "factor_id",
              ],
            },
          },
        }),
      },
    );

    const geminiData = await response.json();

    // Catch API level errors (like invalid keys or rejected payloads)
    if (!response.ok) {
      throw new Error(geminiData.error?.message || "Unknown Gemini API Error");
    }

    const rawText = geminiData.candidates[0].content.parts[0].text;
    const cleanJson = rawText.replace(/```json/g, "").replace(/```/g, "")
      .trim();

    return new Response(cleanJson, {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    console.error("❌ Bill Scanner Error:", errorMessage);
    return new Response(JSON.stringify({ error: errorMessage }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 400,
    });
  }
});
