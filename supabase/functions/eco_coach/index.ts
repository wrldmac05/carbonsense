// deno-lint-ignore-file
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function normalizeCategory(rawCategory?: string): string {
  if (!rawCategory || !rawCategory.trim()) return "General";
  const cat = rawCategory.trim().toLowerCase();
  if (
    cat.includes("transport") || cat.includes("commute") ||
    cat.includes("travel") || cat.includes("car") || cat.includes("vehicle")
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

    // 1. DATA FETCH: LIFESTYLE PROFILE
    const { data: lifestyle } = await supabase
      .from("lifestyle_profiles")
      .select("diet_type, commute_type, has_car")
      .eq("user_id", user_id)
      .maybeSingle();

    const dietHabit = lifestyle?.diet_type ?? "Unknown";
    const commuteHabit = lifestyle?.commute_type ?? "Unknown";
    const hasCar = lifestyle?.has_car ?? false;

    // 2. DATA FETCH: ALL ACTIVITY LOGS
    const { data: allLogs, error: logErr } = await supabase
      .from("activity_logs")
      .select("total_co2e, logged_at, emission_factors(category)")
      .eq("user_id", user_id);

    if (logErr) {
      console.error("Error fetching logs:", logErr);
    }

    const logsList = allLogs || [];
    const totalHistoricalCo2 = logsList.reduce(
      (sum, log) => sum + (Number(log.total_co2e) || 0),
      0,
    );
    const totalLogCount = logsList.length;

    const ytdLogs = logsList.filter((log) => {
      if (!log.logged_at) return false;
      return new Date(log.logged_at).getFullYear() === currentYear;
    });

    const ytdCo2 = ytdLogs.reduce(
      (sum, log) => sum + (Number(log.total_co2e) || 0),
      0,
    );

    const displayFootprint = ytdCo2 > 0 ? ytdCo2 : totalHistoricalCo2;

    // ==========================================
    // TASK 1: DAILY GENERAL INSIGHT
    // ==========================================
    const currentMonthLogs = ytdLogs.filter(
      (log) => new Date(log.logged_at).getMonth() === currentMonthIndex,
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

    (currentMonthLogs.length > 0 ? currentMonthLogs : ytdLogs).forEach(
      (log) => {
        const rawCat = (log as any).emission_factors?.category;
        const cat = normalizeCategory(rawCat);
        categoryTotals[cat] = (categoryTotals[cat] || 0) +
          (Number(log.total_co2e) || 0);
      },
    );

    let topCategory = "None";
    let topCo2 = 0;
    Object.entries(categoryTotals).forEach(([cat, val]) => {
      if (val > topCo2) {
        topCo2 = val;
        topCategory = cat;
      }
    });

    if (topCategory === "None") topCategory = "Energy";

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
- Active Footprint: ${
            displayFootprint.toFixed(1)
          } kg CO2e across ${totalLogCount} total logs
- Current Month Daily Average: ${dailyAvg.toFixed(1)} kg CO2e/day
- Top Emissions Source Category: ${topCategory} (${topCo2.toFixed(1)} kg CO2e)

TASK:
Respond with ONLY valid JSON, no markdown code fences, no text before or after it, matching exactly this shape:
{"headline": "one short encouraging sentence, under 16 words, no numbers", "detail": "2-3 plain sentences: a habit assessment that explicitly references their actual diet habit (\\"${dietHabit}\\") and commute habit (\\"${commuteHabit}\\"), then one specific daily tip targeted at the ${topCategory} category"}

PERSONALIZATION RULES:
1. Ground the assessment in the real diet and commute tags above.
2. The tip must be consistent with existing habits: never suggest something they are already doing.
3. If a habit tag is "Unknown" or "Analyzing...", write around it.

STRICT ACCURACY RULES:
1. NEVER use the words "zero", "effectively at zero", "negligible", or "zero footprint".
2. Do not restate or invent numbers inside the JSON string values.
3. No markdown formatting inside the JSON string values.
`.trim();

          const geminiUrl =
            `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${geminiKey}`;

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
          const rawText =
            geminiData.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
          const cleanedText = rawText.replace(/```json|```/g, "").trim();

          let parsedAi: { headline: string; detail: string };
          try {
            parsedAi = JSON.parse(cleanedText);
          } catch {
            parsedAi = {
              headline: "Your eco-coach has an update",
              detail: rawText,
            };
          }

          const structuredGeneral = {
            headline: parsedAi.headline,
            detail: parsedAi.detail,
            stat1_label: "Active footprint",
            stat1_value: `${displayFootprint.toFixed(1)} kg CO2e`,
            stat2_label: "Top category",
            stat2_value: topCategory,
          };

          await supabase.from("ai_prescriptions").update({
            ai_text: JSON.stringify(structuredGeneral),
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
    // TASK 2: END-OF-MONTH SUMMARY (Previous Month)
    // ==========================================
    const lastMonthDate = new Date(
      today.getFullYear(),
      today.getMonth() - 1,
      1,
    );
    const lastMonthIndex = lastMonthDate.getMonth();
    const lastMonthYear = lastMonthDate.getFullYear();
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

    const targetContext = `month_${lastMonthIndex}_${lastMonthYear}`;

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
          // Filter logs directly in memory matching Flutter's month resolution
          const lastMonthLogs = logsList.filter((log) => {
            if (!log.logged_at) return false;
            const logDate = new Date(log.logged_at);
            return (
              logDate.getFullYear() === lastMonthYear &&
              logDate.getMonth() === lastMonthIndex
            );
          });

          const monthFootprint = lastMonthLogs.reduce(
            (sum, log) => sum + (Number(log.total_co2e) || 0),
            0,
          );
          const monthLogCount = lastMonthLogs.length;
          const daysInLastMonth = new Date(
            lastMonthYear,
            lastMonthIndex + 1,
            0,
          ).getDate();
          const monthDailyAvg = monthFootprint / daysInLastMonth;

          const lastMonthCategoryTotals: Record<string, number> = {
            Transport: 0,
            Diet: 0,
            Energy: 0,
            General: 0,
          };

          lastMonthLogs.forEach((log) => {
            const rawCat = (log as any).emission_factors?.category;
            const cat = normalizeCategory(rawCat);
            lastMonthCategoryTotals[cat] = (lastMonthCategoryTotals[cat] || 0) +
              (Number(log.total_co2e) || 0);
          });

          let lastMonthTopCategory = "None";
          let lastMonthTopCo2 = 0;
          Object.entries(lastMonthCategoryTotals).forEach(([cat, val]) => {
            if (val > lastMonthTopCo2) {
              lastMonthTopCo2 = val;
              lastMonthTopCategory = cat;
            }
          });

          if (lastMonthTopCategory === "None") lastMonthTopCategory = "General";

          const monthlyPrompt = `
You are CarbonSense, an AI Eco-Coach companion. Do not introduce yourself.

MONTHLY PERFORMANCE DATA (${monthNames[lastMonthIndex]} ${lastMonthYear}):
- Total Monthly Footprint: ${monthFootprint.toFixed(2)} kg CO2e
- Daily Average: ${monthDailyAvg.toFixed(2)} kg CO2e/day
- Total Logged Activities: ${monthLogCount} logs
- Primary Emissions Driver: ${lastMonthTopCategory} (${
            lastMonthTopCo2.toFixed(2)
          } kg CO2e)
- User Lifestyle Tags: Diet="${dietHabit}", Commute="${commuteHabit}"

TASK:
Respond with ONLY valid JSON, no markdown code fences, no text before or after it, matching exactly this shape:
{"headline": "one short sentence naming how ${
            monthNames[lastMonthIndex]
          } went, under 16 words, no numbers", "detail": "2-3 plain sentences: how their actual diet habit (\\"${dietHabit}\\") and commute habit (\\"${commuteHabit}\\") shaped the month, then one actionable goal for lowering ${lastMonthTopCategory} impact next month"}

PERSONALIZATION RULES:
1. Ground the summary in the real diet and commute tags above.
2. The goal must build on their existing habits, not repeat one back to them.
3. If a habit tag is "Unknown", write around it.

STRICT ACCURACY RULES:
1. Do not restate or invent numbers inside the JSON string values.
2. No markdown formatting inside the JSON string values.
`.trim();

          const geminiUrl =
            `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${geminiKey}`;

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
          const rawText =
            geminiData.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
          const cleanedText = rawText.replace(/```json|```/g, "").trim();

          let parsedAi: { headline: string; detail: string };
          try {
            parsedAi = JSON.parse(cleanedText);
          } catch {
            parsedAi = {
              headline: `Your ${monthNames[lastMonthIndex]} summary is in`,
              detail: rawText,
            };
          }

          const structuredMonthly = {
            headline: parsedAi.headline,
            detail: parsedAi.detail,
            stat1_label: "Monthly footprint",
            stat1_value: `${monthFootprint.toFixed(1)} kg CO2e`,
            stat2_label: "Top category",
            stat2_value: lastMonthTopCategory,
          };

          await supabase.from("ai_prescriptions").update({
            ai_text: JSON.stringify(structuredMonthly),
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
