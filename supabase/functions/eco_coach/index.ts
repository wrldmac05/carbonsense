// deno-lint-ignore-file
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// Helper to normalize category strings across variations
function normalizeCategory(rawCategory?: string): string {
  if (!rawCategory || !rawCategory.trim()) return "General";
  const cat = rawCategory.trim().toLowerCase();
  if (
    cat.includes("transport") || cat.includes("commute") ||
    cat.includes("travel") || cat.includes("car")
  ) {
    return "Transport";
  }
  if (
    cat.includes("diet") || cat.includes("food") || cat.includes("meal") ||
    cat.includes("eat")
  ) {
    return "Diet";
  }
  if (
    cat.includes("energy") || cat.includes("electricity") ||
    cat.includes("power") || cat.includes("utility")
  ) {
    return "Energy";
  }
  return "General";
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const geminiKey = Deno.env.get("GEMINI_API_KEY");
    if (!geminiKey) throw new Error("Missing Gemini API Key");

    const { user_id } = await req.json();
    if (!user_id) throw new Error("Missing user_id");

    const today = new Date();
    const currentYear = today.getFullYear();
    const currentMonthIndex = today.getMonth();
    const startOfToday = new Date(
      today.getFullYear(),
      today.getMonth(),
      today.getDate(),
    ).toISOString();

    let generatedCount = 0;

    // ==========================================
    // DATA FETCH 1: LIFESTYLE PROFILE
    // ==========================================
    const { data: lifestyle } = await supabase
      .from("lifestyle_profiles")
      .select("diet_type, commute_type, has_car")
      .eq("user_id", user_id)
      .maybeSingle();

    const dietHabit = lifestyle?.diet_type ?? "Unknown";
    const commuteHabit = lifestyle?.commute_type ?? "Unknown";
    const hasCar = lifestyle?.has_car ?? false;

    // ==========================================
    // DATA FETCH 2: ACTIVITY LOGS & EMISSION FACTORS
    // ==========================================
    const { data: allLogs, error: logErr } = await supabase
      .from("activity_logs")
      .select("total_co2e, logged_at, emission_factors(category)") // 👈 Removed top-level 'category'
      .eq("user_id", user_id);

    if (logErr) {
      console.error("Error fetching logs:", logErr);
    }

    // 1. Calculate Historical Total
    const totalHistoricalCo2 = allLogs?.reduce((sum, log) =>
      sum + (Number(log.total_co2e) || 0), 0) || 0;
    const totalLogCount = allLogs?.length || 0;

    // 2. Calculate YTD Total
    const ytdLogs = (allLogs || []).filter((log) => {
      if (!log.logged_at) {
        return false;
      }
      return new Date(log.logged_at).getFullYear() === currentYear;
    });

    const ytdCo2 = ytdLogs.reduce(
      (sum, log) => sum + (Number(log.total_co2e) || 0),
      0,
    );

    // 🌟 SMART FALLBACK: If YTD is 0 but historical data exists, use historical total
    const displayFootprint = (ytdCo2 > 0) ? ytdCo2 : totalHistoricalCo2;

    console.log(
      `[DEBUG] User: ${user_id} | Total Logs: ${totalLogCount} | YTD Co2: ${ytdCo2} | Display Co2: ${displayFootprint}`,
    );

    // 3. Calculate Current Month Category Share + Daily Avg
    const currentMonthLogs = ytdLogs.filter((log) =>
      new Date(log.logged_at).getMonth() === currentMonthIndex
    );
    const currentMonthCo2 = currentMonthLogs.reduce(
      (sum, log) => sum + (Number(log.total_co2e) || 0),
      0,
    );
    const dayOfMonth = today.getDate();
    const dailyAvg = currentMonthCo2 / (dayOfMonth || 1);

    const categoryTotals: Record<string, number> = {
      Transport: 0,
      Diet: 0,
      Energy: 0,
      General: 0,
    };

    currentMonthLogs.forEach((log) => {
      const rawCat = (log as any).emission_factors?.category; // 👈 Fixed reference
      const cat = normalizeCategory(rawCat);
      categoryTotals[cat] = (categoryTotals[cat] || 0) +
        (Number(log.total_co2e) || 0);
    });

    let topCategory = "None";
    let topCo2 = 0;
    Object.entries(categoryTotals).forEach(([cat, val]) => {
      if (val > topCo2) {
        topCo2 = val;
        topCategory = cat;
      }
    });

    // 🌟 FALLBACK: If current month has no logs, calculate top category from YTD
    if (topCategory === "None") {
      const ytdCategoryTotals: Record<string, number> = {
        Transport: 0,
        Diet: 0,
        Energy: 0,
        General: 0,
      };
      (ytdLogs || []).forEach((log) => {
        const rawCat = (log as any).emission_factors?.category; // 👈 Fixed reference
        const cat = normalizeCategory(rawCat);
        ytdCategoryTotals[cat] = (ytdCategoryTotals[cat] || 0) +
          (Number(log.total_co2e) || 0);
      });
      Object.entries(ytdCategoryTotals).forEach(([cat, val]) => {
        if (val > topCo2) {
          topCo2 = val;
          topCategory = cat;
        }
      });
      if (topCategory === "None") topCategory = "Energy";
    }

    // ==========================================
    // TASK 1: THE DAILY GENERAL INSIGHT
    // ==========================================
    const { data: latestGeneral } = await supabase
      .from("ai_prescriptions")
      .select("insight_id, created_at, ai_text")
      .eq("user_id", user_id)
      .eq("context_type", "general")
      .order("created_at", { ascending: false })
      .limit(1);

    const needsGeneralGen = !latestGeneral ||
      latestGeneral.length === 0 ||
      latestGeneral[0].created_at < startOfToday ||
      latestGeneral[0].ai_text.includes("Analyzing");

    if (needsGeneralGen) {
      if (
        latestGeneral && latestGeneral.length > 0 &&
        latestGeneral[0].ai_text.includes("Analyzing")
      ) {
        await supabase.from("ai_prescriptions").delete().eq(
          "insight_id",
          latestGeneral[0].insight_id,
        );
      }

      const { data: placeholder, error: insertError } = await supabase
        .from("ai_prescriptions")
        .insert({
          user_id,
          context_type: "general",
          ai_text: "Analyzing your daily impact...",
        })
        .select()
        .single();

      if (!insertError && placeholder) {
        try {
          const generalPrompt = `
You are CarbonSense, an AI Eco-Coach companion. Do not introduce yourself or use generic greetings.

USER TELEMETRY DATA:
- Diet Habit Profile: "${dietHabit}"
- Commute Habit Profile: "${commuteHabit}" (Owns Car: ${hasCar})
- Total Historical Footprint: ${totalHistoricalCo2.toFixed(1)} kg CO2e
- Active Footprint: ${
            displayFootprint.toFixed(1)
          } kg CO2e across ${totalLogCount} total logs
- Current Month Daily Average: ${dailyAvg.toFixed(1)} kg CO2e/day
- Top Emissions Source Category: ${topCategory} (${topCo2.toFixed(1)} kg CO2e)

TASK:
Write an encouraging, conversational, and highly scannable daily insight.
Format your response into EXACTLY two distinct paragraphs with a double line break (\n\n) between them:

Paragraph 1 (Habit Assessment):
- Provide a brief 2-sentence assessment of their lifestyle habits.
- Explicitly acknowledge their actual footprint (**${
            displayFootprint.toFixed(1)
          } kg CO2e**). Praise their active sustainable habits for helping keep emissions down, OR point out areas where they can improve.

Paragraph 2 (Action Step):
- Start with "**💡 Tip for Today:**"
- Provide 1 specific daily tip targeted at their top emissions driver category (${topCategory}) to help them trim emissions further.

STRICT ACCURACY RULES:
1. NEVER use the words "zero", "effectively at zero", "negligible", or "zero footprint".
2. The user's active footprint is **${
            displayFootprint.toFixed(1)
          } kg CO2e**. Treat this as real, measurable impact.
3. Use markdown **bolding** for numbers and key habit tags.
4. Separate Paragraph 1 and Paragraph 2 with a double newline (\n\n).
`.trim();

          const geminiUrl =
            `https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent?key=${geminiKey}`;

          const geminiResponse = await fetch(geminiUrl, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
              contents: [{ parts: [{ text: generalPrompt }] }],
            }),
          });

          if (!geminiResponse.ok) {
            const err = await geminiResponse.text();
            throw new Error(`Gemini API rejected the request: ${err}`);
          }

          const geminiData = await geminiResponse.json();
          const aiResponse = geminiData.candidates[0].content.parts[0].text;

          await supabase.from("ai_prescriptions").update({
            ai_text: aiResponse,
          }).eq("insight_id", placeholder.insight_id);
          generatedCount++;
        } catch (e) {
          await supabase.from("ai_prescriptions").delete().eq(
            "insight_id",
            placeholder.insight_id,
          );
          console.error("Gemini General Error:", e);
        }
      }
    }

    // ==========================================
    // TASK 2: THE END-OF-MONTH SUMMARY
    // ==========================================
    const lastMonthDate = new Date(
      today.getFullYear(),
      today.getMonth() - 1,
      1,
    );
    const lastMonthIndex = lastMonthDate.getMonth();
    const monthNames = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December",
    ];

    const targetContext =
      `month_${lastMonthIndex}_${lastMonthDate.getFullYear()}`;

    const { data: lastMonthTip } = await supabase
      .from("ai_prescriptions")
      .select("insight_id, ai_text")
      .eq("user_id", user_id)
      .eq("context_type", targetContext)
      .limit(1);

    const needsMonthlyGen = !lastMonthTip ||
      lastMonthTip.length === 0 ||
      lastMonthTip[0].ai_text.includes("Generating");

    if (needsMonthlyGen) {
      if (lastMonthTip && lastMonthTip.length > 0) {
        await supabase.from("ai_prescriptions").delete().eq(
          "insight_id",
          lastMonthTip[0].insight_id,
        );
      }

      const { data: placeholder, error: insertError } = await supabase
        .from("ai_prescriptions")
        .insert({
          user_id,
          context_type: targetContext,
          ai_text: "Generating your monthly summary...",
        })
        .select()
        .single();

      if (!insertError && placeholder) {
        try {
          const startDate = new Date(
            lastMonthDate.getFullYear(),
            lastMonthDate.getMonth(),
            1,
          ).toISOString();
          const endDate = new Date(
            lastMonthDate.getFullYear(),
            lastMonthDate.getMonth() + 1,
            0,
            23,
            59,
            59,
          ).toISOString();

          const { data: lastMonthLogs } = await supabase
            .from("activity_logs")
            .select("total_co2e, category, emission_factors(category)")
            .eq("user_id", user_id)
            .gte("logged_at", startDate)
            .lte("logged_at", endDate);

          const monthFootprint = lastMonthLogs?.reduce((sum, log) =>
            sum + (log.total_co2e || 0), 0) || 0;
          const monthLogCount = lastMonthLogs?.length || 0;
          const daysInLastMonth = new Date(
            lastMonthDate.getFullYear(),
            lastMonthDate.getMonth() + 1,
            0,
          ).getDate();
          const monthDailyAvg = monthFootprint / daysInLastMonth;

          const lastMonthCategoryTotals: Record<string, number> = {
            Transport: 0,
            Diet: 0,
            Energy: 0,
            General: 0,
          };
          (lastMonthLogs || []).forEach((log) => {
            const rawCat = (log as any).emission_factors?.category ||
              log.category;
            const cat = normalizeCategory(rawCat);
            lastMonthCategoryTotals[cat] = (lastMonthCategoryTotals[cat] || 0) +
              (log.total_co2e || 0);
          });

          let lastMonthTopCategory = "None";
          let lastMonthTopCo2 = 0;
          Object.entries(lastMonthCategoryTotals).forEach(([cat, val]) => {
            if (val > lastMonthTopCo2) {
              lastMonthTopCo2 = val;
              lastMonthTopCategory = cat;
            }
          });

          const monthlyPrompt = `
You are CarbonSense, an AI Eco-Coach companion. Do not introduce yourself.

MONTHLY PERFORMANCE DATA (${
            monthNames[lastMonthIndex]
          } ${lastMonthDate.getFullYear()}):
- Total Monthly Footprint: ${monthFootprint.toFixed(2)} kg CO2e
- Daily Average: ${monthDailyAvg.toFixed(2)} kg CO2e/day
- Total Logged Activities: ${monthLogCount} logs
- Primary Emissions Driver: ${lastMonthTopCategory} (${
            lastMonthTopCo2.toFixed(2)
          } kg CO2e)
- User Lifestyle Tags: Diet="${dietHabit}", Commute="${commuteHabit}"

TASK:
1. Summarize their performance for ${
            monthNames[lastMonthIndex]
          } in 2 clear sentences. Explain how their active diet and commute habits contributed to their total footprint of **${
            monthFootprint.toFixed(1)
          } kg CO2e**.
2. Propose 1 actionable mitigation goal for the upcoming month to help lower their top category (${lastMonthTopCategory}) impact.
Keep output under 4 sentences.
          `.trim();

          const geminiUrl =
            `https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent?key=${geminiKey}`;

          const geminiResponse = await fetch(geminiUrl, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
              contents: [{ parts: [{ text: monthlyPrompt }] }],
            }),
          });

          if (!geminiResponse.ok) {
            const err = await geminiResponse.text();
            throw new Error(`Gemini API rejected the request: ${err}`);
          }

          const geminiData = await geminiResponse.json();
          const aiResponse = geminiData.candidates[0].content.parts[0].text;

          await supabase.from("ai_prescriptions").update({
            ai_text: aiResponse,
          }).eq("insight_id", placeholder.insight_id);
          generatedCount++;
        } catch (e) {
          await supabase.from("ai_prescriptions").delete().eq(
            "insight_id",
            placeholder.insight_id,
          );
          console.error("Gemini Monthly Error:", e);
        }
      }
    }

    return new Response(
      JSON.stringify({ success: true, generated: generatedCount }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (error: any) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
