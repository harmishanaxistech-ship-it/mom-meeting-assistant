const { GoogleGenAI } = require('@google/genai');
const env = require('../../config/env');
const TeamKnowledge = require('../../models/TeamKnowledge');

async function updateTeamKnowledge(userId, momData, meetingId) {
  try {
    const ai = new GoogleGenAI({ apiKey: env.geminiApiKey });
    const knowledgeDoc = await TeamKnowledge.findOne({ userId });
    const existingKnowledge = knowledgeDoc ? knowledgeDoc.learnedContext : '';

    const prompt = `You are a memory extraction AI.
Read the following Minutes of Meeting (MOM).
Extract any new, permanent facts, project definitions, team common-sense rules, or ongoing themes that would be highly useful for an AI to remember for FUTURE meetings.
Do NOT extract temporary action items or specific meeting dates. Focus ONLY on permanent context.
If there is existing knowledge, merge the new facts gracefully without deleting important old facts. Keep the total output concise, under 300 words.

EXISTING KNOWLEDGE:
${existingKnowledge || 'None'}

LATEST MOM:
${JSON.stringify(momData)}

OUTPUT ONLY THE UPDATED PERMANENT KNOWLEDGE (No markdown, no intro):`;

    const candidateModels = ['gemini-3.6-flash'];
    let lastErr;

    for (const currentModel of candidateModels) {
      for (let attempt = 1; attempt <= 3; attempt++) {
        try {
          const response = await ai.models.generateContent({
            model: currentModel,
            contents: prompt,
            config: {
              temperature: 0.2,
            },
          });

          const newKnowledge = response.text.trim();

          await TeamKnowledge.findOneAndUpdate(
            { userId },
            { userId, learnedContext: newKnowledge, lastUpdatedMeeting: meetingId },
            { upsert: true }
          );
          console.log(`[Knowledge Service] Team memory updated successfully using ${currentModel}.`);
          return;
        } catch (err) {
          lastErr = err;
          const isOverload = err.message?.includes('503') || err.message?.includes('429') || err.message?.toLowerCase().includes('high demand') || err.message?.toLowerCase().includes('overloaded') || err.message?.toLowerCase().includes('quota');
          
          if (isOverload && attempt < 3) {
            let waitMs = 2000 * Math.pow(2, attempt - 1);
            if (err.message?.includes('429') || err.message?.toLowerCase().includes('quota')) {
               waitMs = 25000; // Wait 25 seconds for rate limit
            }
            console.warn(`[Knowledge Service] ${currentModel} overloaded. Retrying in ${waitMs}ms (Attempt ${attempt}/3)...`);
            await new Promise(r => setTimeout(r, waitMs));
            continue;
          } else {
            console.warn(`[Knowledge Service] ${currentModel} failed: ${err.message}`);
            break;
          }
        }
      }
    }
    
    
    
    // ULTIMATE FALLBACK TO GROQ IF GEMINI FAILS
    console.warn('[Knowledge Service] All Gemini models failed. Falling back to Groq llama-3.1-8b-instant...');
    try {
      
      const Groq = require('groq-sdk');
      const env = require('../../config/env');
      const groqClient = new Groq({ apiKey: env.groqApiKey || process.env.GROQ_API_KEY });
      
      // Dynamically fetch available model to prevent 404/Decommission errors
      const modelsPage = await groqClient.models.list();
      const activeModels = modelsPage.data.filter(m => !m.id.includes('whisper') && !m.id.includes('vision'));
      const fallbackModel = activeModels.length > 0 ? activeModels[0].id : 'mixtral-8x7b-32768';
      console.log(`[Groq Fallback] Dynamically selected model: ${fallbackModel}`);

      const gRes = await groqClient.chat.completions.create({
        model: fallbackModel,
        messages: [{ role: 'user', content: prompt }],
        temperature: 0.2,
      });

      const newKnowledge = gRes.choices[0]?.message?.content?.trim() || '';
      if (newKnowledge !== 'NO_NEW_RULES') {
        await TeamKnowledge.findOneAndUpdate(
          { userId },
          { userId, learnedContext: newKnowledge, lastUpdatedMeeting: meetingId },
          { upsert: true }
        );
        console.log('[Knowledge Service] Team memory updated successfully using Groq.');
      }
    } catch (groqErr) {
      console.error('[Knowledge Service] Groq fallback failed:', groqErr.message);
    }
  } catch (outerErr) {

    console.error('[Knowledge Service] Critical failure:', outerErr.message);
  }
}

module.exports = { updateTeamKnowledge };
