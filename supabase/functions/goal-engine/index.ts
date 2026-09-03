import { serve } from "std/http/server.ts";
import { createClient } from "@supabase/supabase-js";
import { GoogleGenerativeAI } from "@google/generative-ai";
import { GoogleAuth } from "google-auth-library";

serve(async (_req: Request) => {
  try {
    console.log("⚙️ --- AI BATCH GOAL ENGINE STARTING ---");

    // 1. Initialize Clients
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    const genAI = new GoogleGenerativeAI(Deno.env.get("GEMINI_API_KEY") ?? "");
    const geminiModel = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });

    // 2. Setup Firebase Auth (HTTP v1 API)
    const serviceAccountStr = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_KEY");
    if (!serviceAccountStr) throw new Error("Missing Firebase Service Account");

    let serviceAccount = JSON.parse(serviceAccountStr);
    if (typeof serviceAccount === "string") {
      serviceAccount = JSON.parse(serviceAccount);
    }

    if (!serviceAccount.private_key) {
      throw new Error("Error: private_key is missing from the secret.");
    }

    const privateKey = serviceAccount.private_key.replace(/\\n/g, "\n");

    const firebaseAuth = new GoogleAuth({
      credentials: {
        client_email: serviceAccount.client_email,
        private_key: privateKey,
      },
      scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
    });

    const now = new Date();
    const thirtyDaysAgo = new Date(now.getTime() - (30 * 24 * 60 * 60 * 1000))
      .toISOString();

    // Query users due for evaluation
    const { data: profiles, error: profileError } = await supabaseClient
      .from("user_profiles")
      .select(
        "user_id, display_name, monthly_co2_target, target_updated_at, fcm_token, push_enabled",
      )
      .lte("target_updated_at", thirtyDaysAgo);

    if (profileError) throw profileError;

    if (!profiles || profiles.length === 0) {
      console.log("✅ No users are due for evaluation today.");
      return new Response(
        JSON.stringify({ message: "No evaluations needed" }),
        { status: 200 },
      );
    }

    console.log(`📊 Found ${profiles.length} users due for evaluation.`);

    // Process each eligible user
    for (const profile of profiles) {
      const lastUpdate = new Date(profile.target_updated_at);
      const evaluationEnd = new Date(
        lastUpdate.getTime() + (30 * 24 * 60 * 60 * 1000),
      );
      const currentTarget = profile.monthly_co2_target;
      const userName = profile.display_name || "Eco Warrior";

      // Fetch user's logs for the exact 30-day window
      const { data: logs, error: logsError } = await supabaseClient
        .from("activity_logs")
        .select("total_co2e")
        .eq("user_id", profile.user_id)
        .gte("logged_at", lastUpdate.toISOString())
        .lt("logged_at", evaluationEnd.toISOString());

      if (logsError || !logs || logs.length === 0) {
        // Ghost user logic: update timestamp and skip
        await supabaseClient.from("user_profiles")
          .update({ target_updated_at: evaluationEnd.toISOString() })
          .eq("user_id", profile.user_id);
        continue;
      }

      const actualMonthlyEmissions = logs.reduce(
        // deno-lint-ignore no-explicit-any
        (sum: number, log: any) => sum + Number(log.total_co2e),
        0,
      );

      if (actualMonthlyEmissions <= currentTarget) {
        let newTarget = currentTarget * 0.90;
        if (newTarget < 200.0) newTarget = 200.0;

        if (newTarget < currentTarget) {
          console.log(
            `✅ User ${profile.user_id} SUCCEEDED. New target: ${newTarget}`,
          );

          // 1. Generate AI Message FIRST so it exists before the database update
          let aiMessage =
            `Great job! You stayed under ${currentTarget}kg. Your new goal is ${newTarget}kg.`; // Fallback
          try {
            const prompt =
              `Write a short, exciting push notification (max 130 characters) for a user named ${userName}. They successfully kept their monthly carbon footprint under ${currentTarget} kg, so their new adapted goal is ${
                newTarget.toFixed(0)
              } kg. Make it encouraging and AI-driven. Include exactly one emoji.`;
            const geminiResponse = await geminiModel.generateContent(prompt);
            aiMessage = geminiResponse.response.text().trim();
          } catch (aiError) {
            console.error(
              `⚠️ Gemini generation failed for ${profile.user_id}, using fallback.`,
              aiError,
            );
          }

          // 2. Update Database with the generated aiMessage
          await supabaseClient
            .from("user_profiles")
            .update({
              monthly_co2_target: parseFloat(newTarget.toFixed(2)),
              target_updated_at: evaluationEnd.toISOString(),
              last_goal_message: aiMessage,
              goal_message_dismissed: false,
            })
            .eq("user_id", profile.user_id);

          // 3. Send Push Notification via Firebase
          if (profile.push_enabled && profile.fcm_token) {
            try {
              const token = await firebaseAuth.getAccessToken();

              await fetch(
                `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
                {
                  method: "POST",
                  headers: {
                    "Content-Type": "application/json",
                    "Authorization": `Bearer ${token}`,
                  },
                  body: JSON.stringify({
                    message: {
                      token: profile.fcm_token,
                      notification: {
                        title: "Goal Achieved! 🎉",
                        body: aiMessage,
                      },
                      data: { route: "/dashboard" },
                    },
                  }),
                },
              );
              console.log(`📱 Push notification sent to ${userName}`);
            } catch (fcmError) {
              console.error(
                `🔥 Firebase FCM error for ${profile.user_id}:`,
                fcmError,
              );
            }
          }
        } else {
          // Already at floor - just reset timer
          await supabaseClient.from("user_profiles")
            .update({ target_updated_at: evaluationEnd.toISOString() })
            .eq("user_id", profile.user_id);
        }
      } else {
        // Failed goal - just reset timer
        await supabaseClient.from("user_profiles")
          .update({ target_updated_at: evaluationEnd.toISOString() })
          .eq("user_id", profile.user_id);
      }
    }

    console.log("🏁 --- AI BATCH GOAL ENGINE FINISHED ---");
    return new Response(JSON.stringify({ message: "Evaluations complete" }), {
      status: 200,
    });
  } catch (err) {
    console.error("🔥 Critical Error:", err);
    const errorMessage = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ error: errorMessage }), {
      status: 500,
    });
  }
});
