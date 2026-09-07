# 6.19.25 LLM Meal Planning System Meeting

- **Source:** https://app.notion.com/p/217e3fdb754c8013af44f337ed6e8d8d
- **Ancestor path:** Meetings (data source) → Meetings → (untitled) → (untitled) → Homepage
- **Snapshot as of:** 2025-06-19T16:21:25.433Z
- **Properties:** Type: Feature Discussion · Created time: 2025-06-19T16:20:56.215Z · Created by / Last edited by: (user 6436ea6f-2655-4f2e-9394-a0ed83f94278) · Attendees: (user 14f3bf89-0c1a-434a-9889-8f4df81993e7), (user 6436ea6f-2655-4f2e-9394-a0ed83f94278)
- **No discussions/comments on this page.**

---

## Meeting Minutes

### LLM Meal Planning System Meeting

The meeting discussed the current state and improvement plans for an LLM-based meal planning system, as follows:

1. **System Overview**:
   - **Functionality**: The system uses an LLM to generate meal plans based on user preferences, diet restrictions, and goals. It has a memory manager to handle short and long-term memories, and a messages manager to format prompts according to user type and conversation stage.
   - **Tools**: The LLM can call tools like getting in-season foods, filtering recipes and meals, with parameters defined in advance.
2. **Refactoring Plans**:
   - **Multi-agent Approach**: Break down the system into smaller agents, such as a weather agent or a nutrition agent, to reduce prompt complexity.
   - **Embeddings**: Translate recipe information into vectors and store them in a vector database for easier LLM decision-making.
   - **Tool Improvement**: Enhance tools to enforce constraints and filter results based on user preferences, reducing reliance on the LLM.
3. **Challenges and Issues**:
   - **Custom Meals and External Recipes**: The LLM struggles to create custom meals and recommend external recipes when needed.
   - **Tool Calling**: The LLM doesn't always call tools correctly, leading to incorrect or no results.
   - **Database Completeness**: The database lacks some information like spiciness and tags, causing inconsistencies.
4. **User Interaction and Feedback**:
   - **User Requirements**: The LLM needs to ask users more questions to gather sufficient requirements for better meal planning.
   - **User Satisfaction**: The system should handle user feedback and follow-up questions, and consider adding a probing stage to improve user experience.
5. **Rule Set Iteration**:
   - **LLM Assistance**: Use the LLM to help with data analysis, identify new user types, and generate tags and rules.
   - **Database Storage**: Store LLM suggestions in a database and use them to iterate and improve the rule set over time.
6. **Technical Choices**:
   - **Programming Language**: Python was chosen due to a team member's preference, but there are considerations for switching to JavaScript for production.
   - **LLM Model**: Currently using GPT-4o Mini, as Claude is more expensive and GPT-3.5 Turbo has poor results.

## More Detail

Here is a detailed breakdown of the meeting conversations with key points highlighted, organized by topic and including timestamps, speakers, and specific discussion details:

### 1. System Architecture and Current Functionality

#### Memory Manager and LLM Context Handling

- **03:42–05:15 [Speaker A]**: Discussed the memory manager's role in handling short-term (conversation context, up to 8,000 tokens) and long-term memory (user settings, preferences like diet, meal likes). The API passes a conversation ID to load or create new conversations, fetching user data (e.g., vegan status, preferred recipes) from a database.
- **07:08–07:31 [Speaker A & B]**: Confirmed the system currently has two stages: **greeting stage** and **meal presentation stage**, with plans to add more. The messages manager uses these stages to format prompts.

#### Prompt Design for User Types

- **10:01–11:54 [Speaker A]**: Explained the prompt template structure: a core prompt plus additions based on user type (e.g., endurance athlete, busy user, strength training). For example, an endurance athlete's prompt includes nutrition considerations, while a busy user's focuses on time efficiency. Only two stages are implemented, with 13 user types planned but not fully set up.
- **12:40–13:31 [Speaker A & B]**: Noted that the LLM sometimes gets confused by button definitions in prompts (e.g., conflicting instructions), leading to inconsistent responses. The front end may need to handle button logic instead of relying on the LLM.

### 2. Tool Integration and LLM Interaction

#### Tool Registry and Parameter Handling

- **15:15–17:20 [Speaker A]**: The LLM can call tools like `get_recipes_filtered` and `get_meals_filtered`, which accept parameters (e.g., min cook time, diet tags). The tools registry defines each tool's description and parameters, and the LLM translates user queries (e.g., "fast food") into these parameters.
- **18:29–19:26 [Speaker A & B]**: Clarified that the LLM does not generate SQL directly but passes parameters to tools, which build queries. For example, "fast" translates to `min_cook_time < 300 seconds`.

#### Tool Calling Challenges

- **23:13–23:50 [Speaker A & B]**: The LLM sometimes passes incorrect parameters (e.g., missing required fields), leading to failed queries. The team plans to enforce parameter validation in tools.
- **55:07–56:27 [Speaker A]**: The LLM struggles to recommend external recipes when database results are missing and may not call tools correctly (e.g., relying on incomplete tags).

### 3. Refactoring Plans (Key Action Items)

#### 1. Multi-Agent System

- **45:45–48:32 [Speaker A]**: Proposes breaking the system into agents (e.g., master planner, nutrition agent, weather agent) to reduce prompt complexity. Frameworks like `in8in` are being considered, but they are new and not production-ready.

#### 2. Embeddings and Vector Databases

- **49:18–51:56 [Speaker A]**: Plans to use embeddings to convert recipe data (title, ingredients, nutrition) into vectors stored in a database (e.g., Postgres, Pinecone). This would reduce token usage and help the LLM make faster decisions.

#### 3. Tool Enhancement

- **53:44 [Speaker A]**: Aims to improve tools to enforce constraints (e.g., allergy filtering) and score results, reducing reliance on the LLM for filtering.

#### 4. Database and Tagging Issues

- **57:09–62:05 [Speaker A & B]**: The database lacks comprehensive tags (e.g., spiciness, vegan labels for all recipes), causing filtering errors. The team plans to use the LLM to automatically generate and refine tags for recipes.

#### 5. User Interaction and Feedback Loop

- **66:00–67:00 [Speaker A]**: The memory manager saves user conversations, allowing the LLM to handle follow-up questions. A "probing stage" is considered to gather more user requirements before presenting meals.
- **73:33–75:35 [Speaker A & B]**: Proposes using the LLM to analyze user feedback, identify new user types, and iterate on rules. Feedback would be stored in a database to evolve the system over time.

#### 6. Technical Choices and Challenges

##### Programming Language

- **82:26–83:42 [Speaker A]**: Python was chosen for prototyping due to a team member's expertise, but JavaScript is considered for production (better for asynchronous calls). Python's deployment challenges (e.g., synchronous operations) are acknowledged.

##### LLM Model Selection

- **84:31–85:41 [Speaker A]**: Currently using GPT-4o Mini; Claude is too expensive, and GPT-3.5 Turbo yields poor results. The team is testing GPT-4o Mini for accuracy.

#### 7. Next Steps and Action Items

- **63:40–64:35 [Speaker A]**: Prioritize implementing multi-agent architecture, creating recipe embeddings, and enhancing tool constraints.
- **81:16–82:20 [Speaker A]**: Share code on Bitbucket and schedule a follow-up meeting next week for progress updates.
- **90:35–91:05 [Speaker A & B]**: Summarize meeting notes on Notion and use tools to generate meeting recaps for feedback.

### Key Takeaways

- The system relies on LLM prompts and tool calls to generate meal plans, but current limitations include inconsistent tool usage, database gaps, and complex prompt management.
- Refactoring focuses on modularizing the system, leveraging embeddings for efficiency, and improving tool reliability.
- User feedback and automated tagging will be critical for long-term system improvement.
