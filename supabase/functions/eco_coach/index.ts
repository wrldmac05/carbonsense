// deno-lint-ignore-file
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

serve(async (_req: Request) => {
  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    const supabase = createClient(supabaseUrl, supabaseServiceKey)
    
    const geminiKey = Deno.env.get('GEMINI_API_KEY')
    if (!geminiKey) throw new Error("Missing Gemini API Key")

    const today = new Date()
    today.setHours(0, 0, 0, 0)
    
    const { data: logs, error: logError } = await supabase
      .from('activity_logs')
      .select('user_id, total_co2e, factor_id')
      .gte('logged_at', today.toISOString())

    if (logError || !logs || logs.length === 0) {
      return new Response("No logs today.", { status: 200 })
    }

    const userLogs = logs.reduce((acc: Record<string, any[]>, log: any) => {
      acc[log.user_id] = acc[log.user_id] || []
      acc[log.user_id].push(log)
      return acc
    }, {})

    for (const userId in userLogs) {
      const footprint = userLogs[userId].reduce((sum: number, log: any) => sum + log.total_co2e, 0)
      const prompt = `You are CarbonSense, an empathetic eco-coach. A user generated ${footprint.toFixed(2)} kg of CO2 today based on their activities. Write a short, encouraging 2-sentence insight about their footprint and one actionable tip for tomorrow. Keep it friendly and concise.`
      
      const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${geminiKey}`
      const geminiResponse = await fetch(geminiUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ contents: [{ parts: [{ text: prompt }] }] })
      })

      if (!geminiResponse.ok) {
        const errText = await geminiResponse.text()
        throw new Error(`Google API Error: ${errText}`)
      }

      const geminiData = await geminiResponse.json()
      const aiResponse = geminiData.candidates[0].content.parts[0].text

      // ✅ THE FINAL FIX: Using your exact ai_text column!
      const { error: insertError } = await supabase.from('ai_prescriptions').insert({
        user_id: userId,
        ai_text: aiResponse
      })

      if (insertError) {
         throw new Error(`Database Rejected the Save: ${insertError.message} | Hint: Check your column names!`)
      }
    }

    return new Response(JSON.stringify({ success: true, message: "AI Prescriptions generated AND successfully saved!" }), {
      headers: { "Content-Type": "application/json" },
    })

  } catch (error: any) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    })
  }
})