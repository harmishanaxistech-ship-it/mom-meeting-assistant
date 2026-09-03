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
   * 1. Multi-Task Directives & Colloquial Gujarati / Hindi Task Assignment (e.g., "Harmish, iOS ma invess deploy process and beeline ma 25 mail create kari ne testing ma muki de je").
   * 2. Splitting Compound / Multi-Action Dialogue into Individual Action Items.
   * 3. Continuous Historical Context Learning for Daily / Recurring Meetings.
   * 4. Multi-Directional Peer-to-Peer & Manager Task Delegation.
   * 5. General Team Discussions, Brainstorming & Open Debates captured thoroughly.
   * 6. Exact phonetic name normalization (e.g., "Jai" -> "Jay", "Harmish" -> "Harmish", "Vijay" -> "Vijay") matching official attendees.
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
You are a senior executive secretary and intelligent meeting analyst specialized in multi-speaker daily technical meetings conducted in English, Gujarati (ગુજરાતી), Hindi (हिन्दी), or code-switched Hinglish/Gujlish.

CRITICAL INSTRUCTIONS FOR COLLOQUIAL GUJARATI/HINDI TASK DELEGATION & MULTI-ACTION DIRECTIVES:

1. **COLLOQUIAL GUJARATI & HINDI TASK ASSIGNMENT DETECTION**:
   - In Indian software team meetings, tasks are often given conversationally at the end or middle of discussions.
   - Example 1 (Gujarati): "Vijay says to Harmish: 'Harmish, iOS ma invess deploy process and beeline ma 25 mail create kari ne testing ma muki de je'".
     -> YOU MUST EXTRACT BOTH TASKS FOR HARMISH:
        Task A: "Deploy invess process on iOS" (Owner: Harmish)
        Task B: "Create 25 test emails in Beeline and put for QA testing" (Owner: Harmish)
   - Example 2 (Gujarati): "આ કામ પતી જાય એટલે તું સર્વર પર અપડેટ મૂકી દેજે" -> Identify who was addressed and create the task.
   - Example 3 (Hindi): "यह टास्क होने के बाद एपीआई टेस्ट करके डिप्लॉय कर देना" -> Extract the deployment & testing task.
   - ANY statement where Person A tells Person B to do something ("કરી દેજે", "કરી નાખજે", "જોઈ લેજે", "ટેસ્ટિંગ માં મૂકી દેજે", "બનાવી દેજે", "કર લેના", "દેખ લેના", "ડિપ્લોય કરના") MUST be extracted as an explicit Action Item with Person B as the owner!

2. **SPLIT COMPOUND / MULTI-TASK STATEMENTS**:
   - When a speaker gives multiple instructions in a single sentence (e.g. "Do X, and also create Y, and deploy Z"), do NOT lump them into one vague item. Split them into clean, individual, actionable tasks assigned to that person.

3. **GENERAL DISCUSSION & CONVERSATION DETAIL**:
   - Every project discussion, technical challenge, progress update, or side conversation that happens before, during, or after tasks are given MUST be documented under 'keyDiscussionPoints'.
   - State clearly which team member discussed what topic.

4. **EXACT PARTICIPANT NAME MATCHING & NORMALIZATION**:
   - The ONLY official, verified attendees of this meeting are: [${participantsList}].
   - If someone in the transcript speaks a name phonetically (e.g. "Jai" vs "Jay", "Raj" vs "Rajesh", "Priya" vs "Preeya", "Harsh" vs "Hrush", "Amit" vs "Ameet", "Vijay" vs "Vijay", "Harmish" vs "Harmish"), you MUST match and normalize it to the EXACT SPELLING in the verified attendees list: [${participantsList}].
   - Output ONLY the exact names from [${participantsList}]. NEVER output misspelled phonetic variations!

5. **EXHAUSTIVE DETAILS & ZERO MISSED POINTS**:
   - Provide a comprehensive multi-paragraph Executive Summary covering background, attendee updates, all technical tasks, and meeting conclusions.
   - Detail every single discussion under keyDiscussionPoints with attendee names and technical metrics.
   - Capture all decisions, action items (with owner and deadline), pending blockers, risks, and next steps.

Return ONLY valid JSON matching this exact structure with NO markdown formatting or backticks:
{
  "meetingSummary": "Comprehensive, multi-paragraph detailed executive summary covering all attendee updates, general discussions, colloquial task assignments, and meeting conclusions.",
  "agenda": [
    "Agenda item 1",
    "Agenda item 2"
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
      "task": "Exhaustive, clear task description in professional English (e.g., 'Deploy invess process on iOS', 'Create 25 test emails in Beeline and submit for QA testing')",
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
    "Immediate operational next step"
  ],
  "nextMeeting": {
    "date": "YYYY-MM-DD or empty string",
    "time": "HH:MM AM/PM or empty string"
  },
  "conclusion": "Detailed closing statement summarizing achievements, team alignment, and momentum."
}
`;

    const userPrompt = `
Meeting Title: ${meetingData.title}
Meeting Type: ${meetingData.meetingType}
Location: ${meetingData.location || 'N/A'}
Official Verified Attendees: ${participantsList}
Meeting Agenda / Description: ${meetingData.agenda || 'N/A'}
${historyContextBlock}

Full Meeting Transcript to Analyze:
${rawTranscript || 'No transcript text available.'}

Extract all discussions and every single assigned task (including all conversational Gujarati/Hindi task instructions like "કરી દેજે", "ટેસ્ટિંગ માં મૂકી દેજે", etc.).
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
        // Phonetic / fuzzy match (e.g. "jai" -> "Jay", "harmish" -> "Harmish")
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
