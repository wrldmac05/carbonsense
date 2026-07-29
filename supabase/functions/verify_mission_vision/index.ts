import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

serve(async (req) => {
  try {
    // 1. Swap task_description for vision_criteria
    const { image_base64, vision_criteria } = await req.json();

    if (!image_base64 || !vision_criteria) {
      return new Response(
        JSON.stringify({ error: "Missing image_base64 or vision_criteria" }),
        { status: 400, headers: { "Content-Type": "application/json" } },
      );
    }

    const apiKey = Deno.env.get("GEMINI_API_KEY");
    if (!apiKey) {
      throw new Error("GEMINI_API_KEY is not configured in Supabase secrets.");
    }

    // 2. Streamlined, unambiguous prompt
    const prompt =
      `You are an AI validation engine for an environmental tracking system. 
Analyze the provided image. Does it clearly show: ${vision_criteria}?

Respond ONLY with a valid JSON object in the exact format below:
{
  "is_verified": true or false,
  "reason": "A strict 1-sentence explanation of what you see that proves or disproves the criteria."
}`;

    const geminiResponse = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${apiKey}`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          // 3. Force Gemini to return pure JSON without markdown wrappers
          generationConfig: {
            response_mime_type: "application/json",
          },
          contents: [
            {
              parts: [
                { text: prompt },
                {
                  inline_data: {
                    mime_type: "image/jpeg",
                    data: image_base64,
                  },
                },
              ],
            },
          ],
        }),
      },
    );

    if (!geminiResponse.ok) {
      const errText = await geminiResponse.text();
      throw new Error(`Gemini API error: ${errText}`);
    }

    const data = await geminiResponse.json();

    // Because response_mime_type is JSON, we can safely parse the output directly
    const resultText = data.candidates?.[0]?.content?.parts?.[0]?.text ?? "{}";
    const resultJson = JSON.parse(resultText);

    return new Response(
      JSON.stringify(resultJson),
      { headers: { "Content-Type": "application/json" } },
    );
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error);

    return new Response(
      JSON.stringify({ error: errorMessage }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});
