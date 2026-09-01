# Feature discussion - mealplanning (Meeting, 2026-04-07)

Source: https://app.notion.com/p/33be3fdb754c80acaceefa2d1da27805
Parent: Meetings database → 📊 Business & Operations
Meeting date: 2026-04-07
Category: Feature
Attendees: 3 users (mentions unresolved to names via user:// URLs)
Created by: user 9e413a30-6cf5-4637-bac5-a70d90a9653a (xh.analytics@gmail.com)

Note: the transcript itself was not retrievable via this tool (Notion returned "Transcript omitted" and pointed at the meeting-note URL); only the AI-generated meeting summary below was retrievable.

## Meal Planning App Design Discussion — Summary

### Action Items
- [ ] Team to finalize design direction by Friday
- [ ] Each team member to develop their own design concept
- [ ] Create a checklist to evaluate if designs meet established goals
- [ ] Share interview transcripts to Notion for workflow analysis

### User Research Findings (reviewed at this meeting)
Team reviewed interview transcripts revealing key insights about endurance athletes' meal planning needs:
- **Unstructured eating patterns**: Eating outside of training is very inconsistent and intuitive, often an afterthought
- **Decision fatigue**: Athletes want a "no-brain pay card" rather than heavy manual tracking
- **Performance impact**: Daily eating patterns sometimes directly hurt performance due to weight control mindset affecting meal choices
- **Real-life constraints**: Meals are shaped by family situations - athletes won't cook separate meals but could use portion adjustments or modified suggestions

### Core Design Philosophy Debate

**AI-Driven Chatbot Approach** (advocated by one team member)
- Helps reduce mental fatigue in decision-making
- Addresses two decision points: weekly meal planning (based on grocery shopping intervals) and daily meal assignment
- Uses intelligent filtering to present the most important deciding factors first (especially macro composition for endurance athletes)
- Demonstrates understanding of training context, periodization, weather, inventory, and what's on sale
- Builds trust by showing contextual awareness upfront (e.g., "We notice you are tapering for a race now. Next week, we're going to be hiding protein")
- Starts conversations with intelligence rather than generic "How can I help you today?" prompts

**Alternative Approach Concerns** (raised by another team member)
- Worries about the complexity of building truly intelligent AI that users will trust
- Prefers not to present users with a bland chatbot interface
- Questions whether athletes will actively engage and provide enough data for the system to work
- Personal preference for browsing/selecting rather than being told what to eat
- Concern that AI recommendations won't be trustworthy or realistic enough

### Key Technical and Design Considerations

**Data Requirements**
- AI approach requires understanding of user's training cycle, previous meals, preferences, dietary restrictions, and inventory
- Concern that lack of user-provided data could limit effectiveness regardless of approach

**Competitive Landscape**
- Team referenced other meal planning apps and their approaches
- Question raised: "There's so many libraries out there" - what would differentiate this product?

**Testing Challenges**
- A/B testing with AI is significantly harder than testing traditional interfaces
- AI effectiveness depends on recommendation quality, not just interface design
- Recent user testing with Lauren was ineffective because the concepts were too abstract

### Design Concepts Discussed

**Day-Based View** (proposed based on research findings)
- Today view and week view modes
- Context-aware daily recommendations (e.g., "today is a long run day" vs "easy run day")
- Prioritizes specific macros based on training context (protein, fiber, carbs)
- Presents three meal options per category
- Addresses gaps found in interview transcripts

**Hybrid Approach Suggestion**
- Display intelligence at the top of the page (e.g., "Today you need high protein")
- Include daily recommendations at top, weekly view at bottom
- Could look like a library but with smart suggestions surfaced first

**Personalization Features**
- Allow users to save regular recipes and communicate preferences to the system
- System could rotate favorite recipes while introducing new options
- Example: "At least two of my recipes has to be these beans and bowls. You can recommend something else for me"

### Path Forward
Team acknowledged the debate was becoming circular and agreed to:
- Stop trying to convince each other and move forward with experimentation
- Pick one direction and commit fully rather than continuing debate
- Test the approach with users to validate effectiveness
