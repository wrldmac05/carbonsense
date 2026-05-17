// deno-lint-ignore-file
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    const supabase = createClient(supabaseUrl, supabaseServiceKey)
    
    const geminiKey = Deno.env.get('GEMINI_API_KEY')
    if (!geminiKey) throw new Error("Missing Gemini API Key")

    const { user_id } = await req.json()
    if (!user_id) throw new Error("Missing user_id")

    const today = new Date()
    const startOfToday = new Date(today.getFullYear(), today.getMonth(), today.getDate()).toISOString()
    
    let generatedCount = 0;

    // ==========================================
    // TASK 1: THE DAILY GENERAL INSIGHT
    // ==========================================
    const { data: latestGeneral } = await supabase
      .from('ai_prescriptions')
      .select('id, created_at')
      .eq('user_id', user_id)
      .eq('context_type', 'general')
      .order('created_at', { ascending: false })
      .limit(1)

    if (!latestGeneral || latestGeneral.length === 0 || latestGeneral[0].created_at < startOfToday) {
      // 1. PLACEHOLDER LOCK (Blocks duplicate concurrent requests)
      const { data: placeholder, error: insertError } = await supabase
        .from('ai_prescriptions')
        .insert({ user_id, context_type: 'general', ai_text: 'Analyzing your daily impact...' })
        .select()
        .single()

      if (!insertError && placeholder) {
        try {
          const { data: logs } = await supabase.from('activity_logs').select('total_co2e').eq('user_id', user_id)
          const footprint = logs?.reduce((sum, log) => sum + log.total_co2e, 0) || 0
          
          const prompt = `You are CarbonSense. But do not introduce your self or anything. Act as a companion that gives user's total historical footprint. The total footprint is ${footprint.toFixed(2)} kg CO2e. Write a short, encouraging 2-sentence general insight summarizing their impact, and give one actionable tip for today.`
          const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${geminiKey}`
          const geminiResponse = await fetch(geminiUrl, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ contents: [{ parts: [{ text: prompt }] }] })
          })
          const geminiData = await geminiResponse.json()
          const aiResponse = geminiData.candidates[0].content.parts[0].text

          // UPDATE the placeholder instead of inserting a new row
          await supabase.from('ai_prescriptions').update({ ai_text: aiResponse }).eq('id', placeholder.id)
          generatedCount++;
        } catch (e) {
          // If Gemini fails, delete the placeholder so it tries again next time
          await supabase.from('ai_prescriptions').delete().eq('id', placeholder.id)
          console.error("Gemini General Error:", e)
        }
      }
    }

    // ==========================================
    // TASK 2: THE END-OF-MONTH SUMMARY
    // ==========================================
    const lastMonthDate = new Date(today.getFullYear(), today.getMonth() - 1, 1)
    const lastMonthIndex = lastMonthDate.getMonth() // 0-11
    const targetContext = `month_${lastMonthIndex}`

    const { data: lastMonthTip } = await supabase
      .from('ai_prescriptions')
      .select('id')
      .eq('user_id', user_id)
      .eq('context_type', targetContext)
      .limit(1)

    if (!lastMonthTip || lastMonthTip.length === 0) {
      // 1. PLACEHOLDER LOCK
      const { data: placeholder, error: insertError } = await supabase
        .from('ai_prescriptions')
        .insert({ user_id, context_type: targetContext, ai_text: 'Generating your monthly summary...' })
        .select()
        .single()

      if (!insertError && placeholder) {
        try {
          const startDate = new Date(lastMonthDate.getFullYear(), lastMonthDate.getMonth(), 1).toISOString()
          const endDate = new Date(lastMonthDate.getFullYear(), lastMonthDate.getMonth() + 1, 0, 23, 59, 59).toISOString()
          
          const { data: monthLogs } = await supabase
            .from('activity_logs').select('total_co2e').eq('user_id', user_id).gte('logged_at', startDate).lte('logged_at', endDate)
          
          const monthFootprint = monthLogs?.reduce((sum, log) => sum + log.total_co2e, 0) || 0
          const monthNames = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
          
          const prompt = `You are CarbonSense, but do not introduce yourself. Act as a companion or an automated reminder. The month of ${monthNames[lastMonthIndex]} just ended. The user emitted a total of ${monthFootprint.toFixed(2)} kg CO2e. Provide a 2-sentence summary of their performance for that month, and suggest a goal for the new month.`
          const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${geminiKey}`
          const geminiResponse = await fetch(geminiUrl, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ contents: [{ parts: [{ text: prompt }] }] })
          })
          const geminiData = await geminiResponse.json()
          const aiResponse = geminiData.candidates[0].content.parts[0].text

          // UPDATE the placeholder
          await supabase.from('ai_prescriptions').update({ ai_text: aiResponse }).eq('id', placeholder.id)
          generatedCount++;
        } catch (e) {
          // Cleanup on failure
          await supabase.from('ai_prescriptions').delete().eq('id', placeholder.id)
          console.error("Gemini Monthly Error:", e)
        }
      }
    }

    return new Response(JSON.stringify({ success: true, generated: generatedCount }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    })

  } catch (error: any) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    })
  }
})