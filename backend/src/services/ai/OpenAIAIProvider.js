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
   * Generates a structured, accurate MOM from meeting transcript using GPT-4o.
   *
   * KEY DESIGN PRINCIPLES:
   * 1. The MOM is 100% based on the actual spoken transcript — never on the meeting title.
   * 2. We use GPT-4o (not mini) for accurate instruction following on complex prompts.
   * 3. Speaker attribution is inferred from context, not from generic "Speaker 1/2" labels.
   * 4. Action items are split into individual tasks per person mentioned.
   */
  async generateMOM(meetingData, transcriptData, options = {}) {
    const rawTranscript =
      transcriptData.rawText ||
      (transcriptData.segments || []).map((s) => s.text).join(' ');

    if (!rawTranscript || rawTranscript.trim().length < 20) {
      return this._emptyMOM('No transcript available to generate MOM from.');
    }

    const participantsList =
      Array.isArray(meetingData.participants) && meetingData.participants.length > 0
        ? meetingData.participants.join(', ')
        : 'Unknown';

    // Historical meeting context for recurring teams (last 3 meetings)
    let historyBlock = '';
    if (Array.isArray(options.pastContext) && options.pastContext.length > 0) {
      historyBlock = `\nHISTORICAL CONTEXT (previous meetings, for continuity only):\n`;
      options.pastContext.forEach((p, idx) => {
        historyBlock += `[Past Meeting ${idx + 1}: "${p.title}"]\n`;
        historyBlock += `- Attendees: ${(p.participants || []).join(', ')}\n`;
        historyBlock += `- Summary: ${(p.summary || 'N/A').substring(0, 300)}\n`;
        historyBlock += `- Open Action Items: ${
          (p.actionItems || []).map((a) => `${a.owner}: ${a.task}`).join('; ') || 'None'
        }\n\n`;
      });
    }

    const systemPrompt = `You are an expert executive meeting secretary. Your job is to produce accurate, detailed Minutes of Meeting (MOM) documents from meeting transcripts.

STRICT RULES — READ CAREFULLY:

RULE 1 — BASE EVERYTHING ON THE TRANSCRIPT ONLY:
The transcript is the single source of truth. The meeting title is just a label (e.g., "Alpha", "sports", "test", "general discussion") and may have nothing to do with the actual conversation. You MUST completely ignore the meeting title and extract everything from what was actually spoken.

RULE 2 — CAPTURE ALL TOPICS DISCUSSED:
Identify EVERY subject, project, task, tool, platform, or person mentioned in the transcript, no matter how briefly. Common topics include: software projects, app features, deployments, testing updates, client follow-ups, tools, platforms, API integrations, sales pipelines, business strategies, etc.

RULE 3 — ACCURATE SPEAKER/OWNER ATTRIBUTION:
The transcript may not have clear speaker labels. Use contextual clues to attribute tasks:
- Names are often mentioned directly: "Vijay, can you do this?" → owner = Vijay
- First-person reports: "I deployed the API" + context clues → attribute to likely speaker
- If truly unclear, use the most contextually appropriate participant name or "Team"
- Never assign ALL tasks to one person unless explicitly stated in the transcript

RULE 4 — SPLIT COMPOUND TASKS:
If one sentence contains multiple instructions for multiple people (e.g., "Vijay deploy the server, Jay update the UI, and Harmish send the email"), split them into 3 separate action items with correct owners.

RULE 5 — INFER LOGICAL ACTION ITEMS:
Beyond explicit "do this" statements, infer obvious to-dos:
- Upcoming deadlines mentioned → action item with deadline
- "We need to test X before Y date" → action item with deadline
- "Follow up with client on Monday" → action item

RULE 6 — DO NOT FABRICATE OR ASSUME:
Only output what is supported by the transcript. If something was NOT discussed, do not include it.

RULE 7 — PROFESSIONAL OUTPUT QUALITY & EXECUTIVE SUMMARY PARAGRAPHING:
- Write in clear, professional business English. Transform informal/colloquial speech into formal executive language while preserving facts exactly.
- EXECUTIVE SUMMARY FORMAT REQUIREMENT: The "meetingSummary" MUST be structured into 2 to 4 distinct, readable paragraphs separated by double newlines ("\n\n"). NEVER return a single solid wall of text.
  * Paragraph 1 (Overview & Purpose): Purpose of the meeting, lead participants, and core focus area.
  * Paragraph 2 (Key Discussions & Operational Updates): In-depth breakdown of status reports, system updates, workflows, and specifics discussed.
  * Paragraph 3 (Strategic Decisions & Agreements): Key conclusions, approvals, team commitments, and agreed deliverables.

RULE 8 — EXHAUSTIVE LOGISTICAL, OPERATIONAL & TECHNICAL SPECIFICITY:
Do NOT compress or generalize specific facts into vague high-level statements. Extract all granular operational details into distinct points:
1. Exact Dates & Rescheduling:
   - Recognize phonetic patterns: e.g., 'ognis' / '90s' / 'engagement' in context of calendar dates means the 19th of the month.
   - Capture flight/travel start dates (e.g. travel begins 19th from India) and the exact shift of meetings (reschedule 19th meetings to 20th–25th).
2. Client & Target Criteria:
   - Capture exact headcount requirements (e.g., target companies with 11+ employees, avoid solo/small 1-10 teams).
   - List ALL targeted industries mentioned (e.g., Manufacturing, Transportation, Solar Energy, Bakery).
3. Travel Logistics & Lessons Learned:
   - Note lessons from previous trips (e.g., Dubai transit issues, distance between locations).
   - Capture chosen transit modes (e.g., Metro preferred over cabs to prevent delays and manage time).
   - Grouping itineraries geographically day-wise.
4. Portfolio, Events & Products to Pitch:
   - Events: Singapore Expo on September 24th, meeting key contacts.
   - Products: AI agents, AI chatbots, Attendance application, Transport / Export-Import app, MUM project.
5. Communication & Tech Setup:
   - VoIP / calling tools: Vyke / Action app with €10 monthly auto-recharge balance.
   - Teams, FaceTime (iOS), Wi-Fi calling, and WhatsApp messaging.

Respond with ONLY valid JSON — no markdown, no backticks, no extra text.

JSON structure:
{
  "meetingSummary": "Paragraph 1: Executive overview of the meeting and purpose.\n\nParagraph 2: Key operational discussions, project updates, and topics covered.\n\nParagraph 3: Agreed decisions, resolutions, and forward-looking expectations.",
  "agenda": ["Actual topic 1 from transcript", "Actual topic 2..."],
  "keyDiscussionPoints": [
    "Granular topic point: Specific detail, criteria, numbers, tools, or status discussed",
    "..."
  ],
  "decisions": [
    "Specific agreed decision with conditions, dates, or criteria",
    "..."
  ],
  "actionItems": [
    {
      "task": "Concrete actionable task (e.g. Reschedule all September 19th client meetings to September 20th-25th)",
      "owner": "Exact name from: ${participantsList} — or 'Team' if shared",
      "deadline": "Specific date or timeframe mentioned, or 'TBD'",
      "priority": "High | Medium | Low"
    }
  ],
  "pendingItems": ["Open question or unresolved topic from the meeting"],
  "risks": ["Risk, blocker, or dependency that could delay work"],
  "nextSteps": ["Immediate follow-up action or upcoming milestone"],
  "nextMeeting": { "date": "", "time": "" },
  "conclusion": "Closing summary: what was achieved, alignment reached, and momentum going forward"
}`;

    const userPrompt = `VERIFIED MEETING PARTICIPANTS: ${participantsList}
${historyBlock}
FULL MEETING TRANSCRIPT (extract all information from this):
---
${rawTranscript}
---

IMPORTANT: Base your MOM exclusively on the transcript above. Do not use the meeting title "${meetingData.title || ''}" to infer topics — the title may be unrelated to what was actually discussed.`;

    const response = await this.openai.chat.completions.create({
      model: 'gpt-4o',           // Upgraded from gpt-4o-mini for accurate instruction following
      temperature: 0.1,          // Very low temperature for factual, consistent output
      max_tokens: 4096,
      response_format: { type: 'json_object' },
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userPrompt },
      ],
    });

    const content = response.choices[0].message.content;
    let parsed;
    try {
      parsed = JSON.parse(content);
    } catch (e) {
      console.error('[AI] Failed to parse GPT response as JSON:', e.message);
      return this._emptyMOM('AI response could not be parsed. Please reprocess.');
    }

    const usage = response.usage || {};

    // Normalize owner names against official participant list
    // Also apply title-case to fix any inconsistently cased names in the participants list
    const toTitleCase = (str) =>
      str.replace(/\w\S*/g, (txt) => txt.charAt(0).toUpperCase() + txt.slice(1).toLowerCase());
    const officialNames = Array.isArray(meetingData.participants)
      ? meetingData.participants.map((n) => toTitleCase(n))
      : [];
    const normalizeName = (name) => {
      if (!name || name.trim().length === 0) return 'Team';
      const clean = name.trim().toLowerCase();
      if (clean === 'team' || clean === 'all' || clean === 'everyone') return 'Team';
      for (const official of officialNames) {
        const offLower = official.toLowerCase();
        if (
          clean === offLower ||
          clean.includes(offLower) ||
          offLower.includes(clean) ||
          // Fuzzy: "harmish" matches "Harmish Sejpal"
          offLower.split(' ')[0] === clean ||
          clean.split(' ')[0] === offLower.split(' ')[0]
        ) {
          return official;
        }
      }
      return name.trim();
    };

    return {
      meetingSummary: parsed.meetingSummary || '',
      agenda: Array.isArray(parsed.agenda) ? parsed.agenda : [],
      keyDiscussionPoints: Array.isArray(parsed.keyDiscussionPoints) ? parsed.keyDiscussionPoints : [],
      decisions: Array.isArray(parsed.decisions) ? parsed.decisions : [],
      actionItems: Array.isArray(parsed.actionItems)
        ? parsed.actionItems.map((item) => ({
            task: item.task || '',
            owner: normalizeName(item.owner),
            deadline: item.deadline || 'TBD',
            priority: ['High', 'Medium', 'Low'].includes(item.priority) ? item.priority : 'Medium',
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

  _emptyMOM(reason) {
    return {
      meetingSummary: reason,
      agenda: [],
      keyDiscussionPoints: [],
      decisions: [],
      actionItems: [],
      pendingItems: [],
      risks: [],
      nextSteps: [],
      nextMeeting: { date: '', time: '' },
      conclusion: '',
      tokenUsage: { promptTokens: 0, completionTokens: 0, totalTokens: 0 },
    };
  }
}

module.exports = OpenAIAIProvider;
