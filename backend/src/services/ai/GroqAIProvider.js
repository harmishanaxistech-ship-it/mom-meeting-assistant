const Groq = require('groq-sdk');
const AIProvider = require('./AIProvider');
const env = require('../../config/env');

class GroqAIProvider extends AIProvider {
  constructor() {
    super();
    this.groq = new Groq({
      apiKey: env.groqApiKey,
    });
  }

  /**
   * Generates an exhaustive, high-depth structured MOM from meeting details and transcript
   * covering all dialogue, decisions, technical context, and action items thoroughly.
   */
  async generateMOM(meetingData, transcriptData) {
    const rawTranscript =
      transcriptData.rawText ||
      (transcriptData.segments || []).map((s) => `${s.speaker}: ${s.text}`).join('\n');

    const prompt = `
You are a senior executive secretary and meeting analyst. Your task is to produce an **exceptionally detailed, complete, and exhaustive Minutes of Meeting (MOM)** from the transcript below.

CRITICAL INSTRUCTIONS FOR MAXIMUM DEPTH & FULL CONTENT COVERAGE:
1. **Exhaustive Meeting Summary**: Provide a comprehensive 2 to 4 paragraph executive overview that thoroughly describes the objective, core discussions, obstacles, agreements, and overarching outcomes. Do NOT write just 1-2 brief sentences.
2. **Comprehensive Key Discussion Points**: Break down ALL topics discussed into detailed, self-contained bullet points (aim for at least 5 to 12 detailed points depending on length). Each point should capture who said what, the reasoning behind ideas, and specifics (numbers, technologies, client details, metrics).
3. **Explicit Decisions**: Capture every formal or informal decision made during the conversation. If reasons or conditions were attached to a decision, state them clearly.
4. **Action Items**: Extract every single task, assignment, follow-up, or commitment mentioned in the transcript. Identify the exact owner, deadline/timeframe, and priority (High, Medium, Low). If not mentioned, state 'Unassigned' or 'TBD'.
5. **Pending Items & Unresolved Questions**: List any questions left unanswered or topics deferred for future evaluation.
6. **Risks & Blockers**: Document all mentioned technical risks, timeline delays, resource bottlenecks, or dependencies.
7. **Next Steps & Conclusion**: Detail the immediate next operational steps and write a thorough conclusion summarizing the path forward.
8. **No Content Left Behind**: Cover the ENTIRE transcript from the beginning to the end.

Return ONLY valid JSON matching this exact structure with NO markdown ticks or backticks:
{
  "meetingSummary": "Comprehensive, multi-paragraph detailed executive summary covering the entire meeting context, discussions, and outcomes.",
  "agenda": [
    "Comprehensive agenda item 1",
    "Comprehensive agenda item 2"
  ],
  "keyDiscussionPoints": [
    "Detailed discussion topic 1 explaining background, participant opinions, and technical/business details.",
    "Detailed discussion topic 2 explaining specifics, metrics, and considerations.",
    "Detailed discussion topic 3..."
  ],
  "decisions": [
    "Detailed decision 1 with full context and agreed direction",
    "Detailed decision 2..."
  ],
  "actionItems": [
    {
      "task": "Exhaustive task description with full scope of work",
      "owner": "Person name or team responsible",
      "deadline": "Target deadline or date mentioned",
      "priority": "High | Medium | Low"
    }
  ],
  "pendingItems": [
    "Specific open question or pending verification"
  ],
  "risks": [
    "Identified risk, challenge, or dependency"
  ],
  "nextSteps": [
    "Immediate operational next step"
  ],
  "nextMeeting": {
    "date": "YYYY-MM-DD or empty string",
    "time": "HH:MM AM/PM or empty string"
  },
  "conclusion": "Detailed closing statement summarizing meeting achievements, alignment, and expected momentum."
}

Meeting Details:
Title: ${meetingData.title}
Type: ${meetingData.meetingType}
Location: ${meetingData.location || 'N/A'}
Participants: ${(meetingData.participants || []).join(', ') || 'N/A'}
Agenda: ${meetingData.agenda || 'N/A'}

Full Transcript to Analyze:
${rawTranscript || 'General meeting discussion.'}
`;

    const chatCompletion = await this.groq.chat.completions.create({
      messages: [
        {
          role: 'user',
          content: prompt,
        },
      ],
      model: 'openai/gpt-oss-120b',
      temperature: 0.2, // lower temperature for precision, structure and consistency
      max_completion_tokens: 4096, // expanded to 4096 to prevent truncation of full detailed content
      top_p: 1,
      stream: false,
      reasoning_effort: 'medium',
      stop: null,
    });

    let raw = chatCompletion.choices[0]?.message?.content || '{}';
    raw = raw.replace(/```json/g, '').replace(/```/g, '').trim();

    let parsed = {};
    try {
      parsed = JSON.parse(raw);
    } catch (e) {
      console.error('[Groq MOM Parse Error]:', e.message);
    }

    const usage = chatCompletion.usage || {};

    return {
      meetingSummary: parsed.meetingSummary || '',
      agenda: Array.isArray(parsed.agenda) ? parsed.agenda : [],
      keyDiscussionPoints: Array.isArray(parsed.keyDiscussionPoints)
        ? parsed.keyDiscussionPoints
        : [],
      decisions: Array.isArray(parsed.decisions) ? parsed.decisions : [],
      actionItems: Array.isArray(parsed.actionItems)
        ? parsed.actionItems.map((item) => ({
            task: item.task || '',
            owner: item.owner || '',
            deadline: item.deadline || '',
            priority: ['High', 'Medium', 'Low'].includes(item.priority)
              ? item.priority
              : 'Medium',
          }))
        : [],
      pendingItems: Array.isArray(parsed.pendingItems) ? parsed.pendingItems : [],
      risks: Array.isArray(parsed.risks) ? parsed.risks : [],
      nextSteps: Array.isArray(parsed.nextSteps) ? parsed.nextSteps : [],
      nextMeeting: {
        date: parsed.nextMeeting?.date || '',
        time: parsed.nextMeeting?.time || '',
      },
      conclusion: parsed.conclusion || '',
      tokenUsage: {
        promptTokens: usage.prompt_tokens || 0,
        completionTokens: usage.completion_tokens || 0,
        totalTokens: usage.total_tokens || 0,
      },
    };
  }
}

module.exports = GroqAIProvider;
