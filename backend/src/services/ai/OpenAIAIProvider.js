const OpenAI = require('openai');
const AIProvider = require('./AIProvider');
const env = require('../../config/env');

class OpenAIAIProvider extends AIProvider {
  constructor() {
    super();
    this.openai = new OpenAI({
      apiKey: env.openaiApiKey || env.apiKeys.ai,
    });
  }

  /**
   * Generates an exhaustive, high-depth structured MOM from meeting details and transcript using GPT-4o-mini
   * Optimized for:
   * 1. 100% Reality-Grounded Transcript Analysis (Never fabricate or assume topics based purely on title or metadata).
   * 2. Intelligent Proactive To-Dos / Next Actions inference (Predicting logical next steps like client reviews, holiday prep, monday feedbacks).
   * 3. Project / Product Entity Recognition (Invest, B-Line, LJE Sports, Gemini, OpenAI, Groq, etc.).
   * 4. Multi-Task Directives & Colloquial Gujarati / Hindi Task Assignment.
   * 5. Splitting Compound / Multi-Action Dialogue into Individual Action Items.
   * 6. Continuous Historical Context Learning for Daily / Recurring Meetings.
   * 7. Exact phonetic name normalization matching official attendees.
   */
  async generateMOM(meetingData, transcriptData, options = {}) {
    const rawTranscript =
      transcriptData.rawText ||
      (transcriptData.segments || []).map((s) => `${s.speaker}: ${s.text}`).join('\n');

    const participantsList = Array.isArray(meetingData.participants) && meetingData.participants.length > 0
      ? meetingData.participants.join(', ')
      : 'N/A';

    // Build historical context from previous daily meetings for continuous learning
    let historyContextBlock = '';
    if (Array.isArray(options.pastContext) && options.pastContext.length > 0) {
      historyContextBlock = `
HISTORICAL RECURRING MEETING CONTEXT (Learned from previous sessions):
${options.pastContext
  .map(
    (p, idx) => `
[Past Meeting ${idx + 1}: "${p.title}"]
- Attendees: ${(p.participants || []).join(', ')}
- Previous Summary: ${p.summary || 'N/A'}
- Pending / Previous Action Items: ${(p.actionItems || []).map((a) => `${a.owner}: ${a.task} (${a.priority})`).join('; ') || 'None'}
`
  )
  .join('\n')}
Use the above past meeting history to understand ongoing project threads, recurrent topics, and the typical functional roles of ${participantsList}.
`;
    }

    const systemPrompt = `
You are a world-class executive meeting intelligence AI and senior secretary specialized in multilingual meetings conducted in English, Gujarati (ગુજરાતી), Hindi (हिन्दी), and mixed Hinglish/Gujlish.

CRITICAL ARCHITECTURAL RULES:

1. **GROUNDED STRICTLY IN ACTUAL CONVERSATION (NOT THE TITLE)**:
   - Meetings can have misleading, generic, or exploratory titles (e.g., "Alpha", "Tango", "Sales Review", "General Discussion").
   - You MUST extract the summary, discussions, decisions, and action items EXCLUSIVELY based on what the attendees ACTUALLY said in the transcript.
   - If the title says "Sales Review" but the team discussed AI tool testing, LLM comparisons (Gemini vs OpenAI vs Groq), iOS deployment, or project deliverables (Invest, B-Line, LJE Sports), the MOM MUST reflect the actual discussion topics and ignore the misleading title!

2. **RECOGNIZE ALL PROJECT, TOOL, & TOPIC ENTITIES**:
   - Explicitly capture all project names, products, tools, and technical terms mentioned (e.g. Invest, B-Line, LJE Sports, Google Gemini, OpenAI, Groq, Whisper, iOS deployment, test emails).
   - Even if only briefly discussed, mention them under 'keyDiscussionPoints' so leadership has full visibility of all project updates.

3. **INTELLIGENT PROACTIVE TO-DOS & NEXT ACTIONS INFERENCE**:
   - Beyond explicit instructions, infer logical and necessary next steps/to-dos based on context.
   - Example: If a team member is delivering a build before holidays, capture:
     a) Immediate pre-holiday deliverables (e.g., Vijay submitting testing report for LJE Sports).
     b) Monday / post-holiday follow-ups (e.g., Awaiting client feedback, scheduling next testing iteration).
   - Capture these in 'actionItems' and 'nextSteps'.

4. **COLLOQUIAL GUJARATI & HINDI TASK DELEGATION & MULTI-ACTION SPLITTING**:
   - Detect conversational delegation patterns (e.g., "Harmish, iOS ma invess deploy process and beeline ma 25 mail create kari ne testing ma muki de je", "કરી દેજે", "ટેસ્ટિંગ માં મૂકી દેજે", "બનાવી દેજે", "કર લેના", "દેખ લેના").
   - Split compound instructions into separate, clean Action Items with the assigned person as the 'owner'.

5. **EXACT PARTICIPANT ATTRIBUTION & NORMALIZATION**:
   - Official Attendees: [${participantsList}].
   - Match phonetic or casual names (e.g., "Priyanka", "Harmish", "Vijay", "Jay", "Amit") to the official attendee spelling.
   - Clearly attribute who presented or proposed which topic in 'keyDiscussionPoints'.

Return ONLY valid JSON matching this exact structure with NO markdown formatting or backticks:
{
  "meetingSummary": "Comprehensive, multi-paragraph detailed executive summary capturing the REAL discussion topics, speaker contributions, project updates, and strategic outcomes.",
  "agenda": [
    "Actual discussion topic 1",
    "Actual discussion topic 2"
  ],
  "keyDiscussionPoints": [
    "Detailed discussion topic 1 capturing participant contributions, technical/general debates, numbers, and decisions.",
    "Detailed discussion topic 2...",
    "Detailed discussion topic 3..."
  ],
  "decisions": [
    "Explicit decision 1 with agreed conditions and participant alignment",
    "Explicit decision 2..."
  ],
  "actionItems": [
    {
      "task": "Exhaustive, clear task description in professional English",
      "owner": "Exact name from official verified attendees list",
      "deadline": "Target deadline or date mentioned (or TBD)",
      "priority": "High | Medium | Low"
    }
  ],
  "pendingItems": [
    "Unanswered question, open debate point, or topic requiring follow-up verification"
  ],
  "risks": [
    "Identified risk, blocker, timeline delay, or dependency"
  ],
  "nextSteps": [
    "Immediate operational next step / upcoming to-do (e.g. Monday client feedback, model accuracy comparison)"
  ],
  "nextMeeting": {
    "date": "YYYY-MM-DD or empty string",
    "time": "HH:MM AM/PM or empty string"
  },
  "conclusion": "Detailed closing statement summarizing achievements, team alignment, and momentum."
}
`;

    const userPrompt = `
Meeting Title (Reference Only): ${meetingData.title}
Meeting Type: ${meetingData.meetingType}
Location: ${meetingData.location || 'N/A'}
Official Verified Attendees: ${participantsList}
Meeting Agenda / Description: ${meetingData.agenda || 'N/A'}
${historyContextBlock}

Full Meeting Transcript to Analyze:
${rawTranscript || 'No transcript text available.'}

Base your analysis entirely on the actual dialogue in the transcript. Extract all project updates, LLM comparisons, and conversational task directives.
`;

    const response = await this.openai.chat.completions.create({
      model: 'gpt-4o-mini',
      temperature: 0.2,
      max_tokens: 4096,
      response_format: { type: 'json_object' },
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userPrompt },
      ],
    });

    const content = response.choices[0].message.content;
    const parsed = JSON.parse(content);
    const usage = response.usage || {};

    // Helper: Normalize any owner name against official attendee list
    const officialNames = Array.isArray(meetingData.participants) ? meetingData.participants : [];
    const normalizeName = (name) => {
      if (!name || name.trim().length === 0) return 'Unassigned';
      const clean = name.trim().toLowerCase();
      for (const official of officialNames) {
        if (official.toLowerCase() === clean) return official;
        // Phonetic / fuzzy match (e.g. "jai" -> "Jay", "harmish" -> "Harmish", "priyanka" -> "Priyanka")
        if (
          clean.includes(official.toLowerCase()) ||
          official.toLowerCase().includes(clean) ||
          clean.replace(/i/g, 'y') === official.toLowerCase().replace(/i/g, 'y') ||
          clean.replace(/ee/g, 'i') === official.toLowerCase().replace(/ee/g, 'i') ||
          clean.replace(/sh/g, 's') === official.toLowerCase().replace(/sh/g, 's')
        ) {
          return official;
        }
      }
      return name.trim();
    };

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
            owner: normalizeName(item.owner),
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

module.exports = OpenAIAIProvider;
