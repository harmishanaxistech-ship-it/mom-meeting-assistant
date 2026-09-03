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
   * Strictly grounded in the actual spoken audio/transcript, completely decoupled from any misleading meeting titles or descriptions.
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
You are a senior executive secretary and meeting intelligence expert specializing in multi-speaker meetings conducted in English, Gujarati (ગુજરાતી), Hindi (हिन्दी), or code-switched Hinglish/Gujlish.

CRITICAL DIRECTIVES FROM EXECUTIVE LEADERSHIP (PRIYANKA MA'AM & MANAGEMENT):

1. **100% REAL CONVERSATION GROUNDING (NEVER RELY ON THE MEETING TITLE OR CREATION DATA)**:
   - Meeting titles are often placeholder names, codes (e.g. Alpha, Beta, Tango, Charlie), ad-hoc labels, or generic defaults (e.g., "Sales Review Meeting", "General Discussion").
   - You MUST IGNORE the meeting title when determining the subject of the meeting.
   - Summarize and extract points EXCLUSIVELY from what the attendees ACTUALLY spoke in the transcript.
   - If the title says "Sales Review" but Priyanka, Harmish, and Vijay actually discussed:
     - Reviewing the AI meeting tool capabilities
     - Speaker voice recognition vs name introduction
     - Projects discussed: Invest (iOS deployment), B-Line (25 test emails), LJE Sports (testing report)
     - Pre-holiday deliverables vs Monday post-holiday client feedback
     - LLM comparison: Google Gemini vs OpenAI vs Groq
     - Generic news / US politics (e.g. Trump, America)
   - Then the MOM MUST be 100% about the AI tool review, LLM comparison, and project deliverables, with ZERO mention of sales!

2. **MENTION EVERY SINGLE TOPIC, PROJECT, & PERSON (LEAVE ZERO DETAILS OUT)**:
   - Project & Entity Recognition: Capture every project mentioned (Invest, B-Line, LJE Sports, Gemini, OpenAI, Groq, Whisper, iOS deployment, test emails).
   - Side & General Discussions: Capture all exploratory discussions, third-party topics (e.g., news, political commentary, general opinions).
   - Speaker Attribution: Clearly state who contributed what:
     * Priyanka's directives & vision (tool evaluation, comparing 3 LLMs: Gemini vs OpenAI vs Groq, holiday prep logic).
     * Harmish's updates (tool review, current OpenAI & Groq APIs integration).
     * Vijay's updates & suggestions (teams reports, Google Gemini accuracy for translation).

3. **INTELLIGENT TO-DOS & INFERRED LOGICAL ACTION ITEMS**:
   - Extract both explicit instructions AND logical next to-dos based on meeting context:
     * Specific deliverables before 3-day holiday (e.g. Vijay submitting LJE Sports testing report, Harmish deploying iOS Invest and creating 25 emails in B-Line).
     * Start of the week / Monday follow-up to-dos (e.g. Awaiting client feedback on delivered site, scheduling next LLM comparison test).
     * Comparative evaluation to-dos (e.g. Download meeting recording, upload to Google Gemini, compare output against OpenAI & Groq, decide which model to keep).

4. **EXACT PARTICIPANT ATTRIBUTION & NORMALIZATION**:
   - Official Verified Attendees: [${participantsList}].
   - Match phonetic or casual names (e.g., "Priyanka", "Harmish", "Vijay", "Jay", "Amit") to the official attendee spelling.
   - Output ONLY exact official names in 'owner' fields.

5. **COLLOQUIAL GUJARATI & HINDI TASK EXTRACTION & MULTI-ACTION SPLITTING**:
   - Interpret phrases like "કરી દેજે", "ટેસ્ટિંગ માં મૂકી દેજે", "બનાવી દેજે", "કર લેના", "દેખ લેના" as direct tasks.
   - Split compound instructions into separate Action Items with the correct owner.

Return strictly valid JSON conforming to this exact structure with NO markdown formatting or backticks:
{
  "meetingSummary": "Comprehensive, multi-paragraph detailed executive summary capturing the REAL discussion topics, speaker contributions, project updates, and strategic outcomes.",
  "agenda": [
    "Actual discussion topic 1 as spoken",
    "Actual discussion topic 2..."
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
      "task": "Exhaustive, clear task description in professional English (e.g., 'Deploy invess process on iOS', 'Create 25 test emails in Beeline and submit for QA testing', 'Submit LJE Sports website testing report before 3-day holiday', 'Upload meeting audio to Google Gemini and compare output with OpenAI & Groq')",
      "owner": "Exact name from official verified attendees list",
      "deadline": "Target deadline or date mentioned (or TBD / Before holidays / Monday)",
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
Official Verified Attendees: ${participantsList}
${historyContextBlock}

Full Meeting Spoken Transcript to Analyze:
${rawTranscript || 'No transcript text available.'}

Base your entire analysis, summary, discussion points, and action items EXCLUSIVELY on what was spoken in the transcript above. Do not assume or invent anything from the meeting title or creation form.
`;

    const response = await this.openai.chat.completions.create({
      model: 'gpt-4o-mini',
      temperature: 0.15,
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
