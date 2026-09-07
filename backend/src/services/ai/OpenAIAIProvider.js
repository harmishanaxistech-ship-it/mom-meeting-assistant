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

    const systemPrompt = `You are an expert AI Executive Assistant specializing in analyzing raw audio transcripts and generating precise, structured Minutes of Meeting (MOM).

Your task is to convert raw speech-to-text input into an accurate, complete, and professional MOM. Follow these strict guidelines:

1. PHONETIC & CONTEXTUAL ACCURACY:
   - Base everything strictly on the transcript as the single source of truth. Ignore meeting titles if they conflict with spoken content.
   - Carefully resolve phonetically ambiguous words using context (e.g., distinguish dates like "19th" vs. "90s" / "ognis", "20th" vs. "20s", "engagement" vs. "19th").
   - Correct technical jargon, product names, tools, and platforms based on context (e.g., "VoIP", "Vyke", "FaceTime", "MOM project", "Flutter", "Teams", "Attendance app").
   - Accurately map participant names mentioned in dialogue to the verified attendee list.

2. LOGISTICS & ACTIONABLE DETAILS (DO NOT OVER-SUMMARIZE):
   - Extract all specific logistics: travel dates, transit instructions, mode of transport (e.g., Metro vs cabs), communication setups (e.g., VoIP balances like €10, Wi-Fi calling, WhatsApp, Teams, FaceTime).
   - Capture exact numbers and metrics (e.g., employee count filters like 11+ headcount, budget amounts, costs like 0.5 EUR/min).
   - Never omit operational context (e.g., past feedback from previous trips, preferences, geographical clustering of meetings, travel constraints).
   - Capture all target sectors and industries (e.g., manufacturing, transportation, solar energy, bakery) and upcoming events (e.g., Expos).

3. STRUCTURED OUTPUT FORMAT & EXECUTIVE SUMMARY:
   - "meetingSummary": A structured executive summary in 2-3 readable paragraphs separated by double newlines ("\\n\\n") providing a clear overview, operational highlights, and strategic agreements.
   - "keyDiscussionPoints": Grouped logically by topic with a category heading prefix ('Topic Category: Detailed explanation with all facts, figures, tools, dates, and operational criteria'). Never return brief, vague phrases.
   - "decisions": Explicit list of agreed-upon outcomes, approvals, and criteria.
   - "actionItems": Concrete, unambiguous tasks with (task | owner | priority | deadline). Split compound tasks into separate items. Assign each to the specific person responsible (or "Team" if collective).
   - "pendingItems", "risks", "nextSteps", "conclusion": Complete operational closure.

4. TONE & VERIFICATION:
   - Maintain a concise, accurate, and highly objective professional tone.
   - If a specific detail (like an exact name or exact date) is unclear from the audio, state it clearly as "[Unclear / Needs Verification]" rather than guessing.

Respond with ONLY valid JSON — no markdown, no backticks, no extra text.

JSON structure:
{
  "meetingSummary": "Paragraph 1: Executive overview of the meeting and purpose.\n\nParagraph 2: Key operational discussions, project updates, and topics covered.\n\nParagraph 3: Agreed decisions, resolutions, and forward-looking expectations.",
  "agenda": ["Actual topic 1 from transcript", "Actual topic 2..."],
  "keyDiscussionPoints": [
    "Topic Category: Detailed multi-sentence explanation covering all specifics, figures, and logistics discussed",
    "..."
  ],
  "decisions": [
    "Specific agreed decision with conditions, dates, or criteria",
    "..."
  ],
  "actionItems": [
    {
      "task": "Concrete actionable task",
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
