Advanced Agentic Engineering: From Generic Execution to Orchestrated Expertise

Executive Summary

Modern AI agent development is transitioning from ad-hoc prompting toward structured, self-improving systems categorized as "Agent Experts." The persistent limitation of traditional agents—their inability to learn from usage and their tendency to "forget" between sessions—is being addressed through three primary architectural shifts:

1. Context and Expertise Engineering: The implementation of evolving "mental models" (stored as expertise files) and meta-agentic layers (meta-prompts, meta-agents, and meta-skills) that allow agents to build and refine the very systems they inhabit.
2. Deterministic Lifecycle Automation: The use of "hooks" and "justfiles" to enforce project rules, automate repetitive maintenance, and standardize installation processes with human-in-the-loop interactivity.
3. Multi-Agent Orchestration: The deployment of specialized subagents and autonomous "Agent Teams" coordinated via centralized task systems. This allows for parallelized execution, "Builder-Validator" pairings, and high-volume operations isolated from the primary conversation context.

The ultimate objective is "Agentic Engineering" rather than "vibe coding"—creating a reliable, orchestrated layer of intelligence that manages the codebase as a living, executing document.


--------------------------------------------------------------------------------


1. The Paradigm of Agent Experts

The fundamental difference between a generic agent and an Agent Expert is that an expert executes and learns, whereas a generic agent executes and forgets. Expertise is defined as the ability to automate the storage and reuse of expertise at runtime without human intervention.

The Mental Model

True experts do not relearn their craft for every new task; they update a mental model. In an agentic context, this is a data structure (often a YAML or Markdown file) that evolves over time.

* Not a Source of Truth: The mental model is auxiliary; it is a "working memory" file. The true source of truth remains the code itself.
* Validation: Agent experts read their expertise files first and then immediately validate those assumptions against the code before reporting or taking action.
* Persistence: By using expertise files, agents avoid the need for manually updated "global memory files," which often consume excessive context or require constant human maintenance.

Meta-Agentics: The Atoms of Expertise

Every advanced agentic codebase should utilize "meta-agentics"—tools that build the system itself.

* Meta-Prompts: Specialized prompts designed to generate other prompts in a vetted, consistent format.
* Meta-Agents: Agents designed to build and configure other agents (e.g., creating a specialized planner agent).
* Meta-Skills: Skills designed to build other skills (e.g., a skill that automates the creation of front-end/back-end orchestration scripts).


--------------------------------------------------------------------------------


2. Deterministic Control: The Hook System

Hooks provide deterministic control over an agent’s behavior, ensuring specific actions occur at key points in the lifecycle rather than relying on the Large Language Model (LLM) to choose them.

Hook Lifecycle Events

Event	Trigger Point	Common Use Case
SessionStart	When a session begins or resumes	Injecting project-specific context or reminders.
PreToolUse	Before a tool executes	Blocking edits to protected files (e.g., .env).
PostToolUse	After a tool call succeeds	Running a linter or formatter after an edit.
Notification	When Claude needs user input	Sending a desktop notification via shell script.
Stop	When the agent finishes responding	Self-validation of the work completed.
SessionEnd	When a session terminates	Cleaning up temporary artifacts or logs.

Types of Hooks

* Command-based: Executes standard shell commands (e.g., npx prettier --write).
* Prompt-based: Uses a lightweight model (like Haiku) to make a judgment call (e.g., "Is this task actually complete?").
* Agent-based: Spawns a subagent to perform complex verification, such as running a test suite before allowing a "Stop" command.


--------------------------------------------------------------------------------


3. Orchestration Architectures: Subagents and Teams

To handle complex engineering tasks, work must be delegated. There are two primary models for this: Subagents and Agent Teams.

Subagents vs. Agent Teams

Feature	Subagents	Agent Teams
Context	Own context; returns results to caller	Fully independent Claude sessions
Communication	Reports to main agent only	Teammates message each other directly
Coordination	Main agent manages all work	Shared task list with self-coordination
Best For	Focused, high-volume operations	Multi-layer coordination (Frontend/Backend)
Token Cost	Lower (summarized results)	Higher (multiple independent instances)

The Task Management System

A critical advancement in orchestration is the "Task System," which allows a primary agent to manage a structured task list.

* Communication: Agents use task_create, task_get, task_list, and task_update to coordinate.
* Dependencies: Tasks can be blocked or depend on other tasks, allowing for sophisticated parallel workflows.
* Event-Driven: When subagents complete work, they "ping" the primary agent, which can then react in real-time without needing "bash sleep loops."

The Builder-Validator Pattern

A foundational team combination involves two specialized agents:

1. The Builder: Focuses purely on execution and implementation.
2. The Validator: Focused on checking the work, running compilation tests, and ensuring the builder met the specification. Note: This "2x compute" approach significantly increases the trust and reliability of the delivered code.


--------------------------------------------------------------------------------


4. Reliability and Context Engineering

A major challenge is ensuring agents actually "see" and "invoke" the skills and rules provided.

Improving Skill Calling

Research indicates that agent skills are often only called ~50% of the time when relevant. To increase this to 80-100%, engineers should use:

* Persistent Context: Mentioning the skill explicitly in the agents.md or CLAUDE.md file.
* Compressed Indexing: For large frameworks (like Next.js), a compressed index can be injected into the core context that points to structured folders of documentation. This provides the agent with a "map" of available knowledge without overflowing the context window.
* Dynamic Injection: Using the !command syntax in skills to run shell commands (like fetching live GitHub PR diffs) before the prompt is sent to the model.

Standardized Launchpads: Justfiles

"Just" is a command runner used as a launchpad for agentic work. It allows teams to:

* Standardize complex CLI commands with various flags.
* Kick off "Human-in-the-Loop" (HITL) onboarding where the agent asks the user guided questions (e.g., "Fresh database or migrate?").
* Ensure that every engineer (and agent) on a team uses the exact same environment initialization.


--------------------------------------------------------------------------------


5. Implementation Strategy: Setup and Maintenance

The "Setup Hook" is an optional but critical hook for operations that should not run on every session.

* Initialization (--init): Automates the installation of dependencies (uv sync, npm install) and database migrations.
* Maintenance Mode: Periodic workflows for cleaning artifacts, updating vulnerable packages, or running security checks.
* Onboarding: By combining deterministic setup scripts with an agentic "Prime" command, new engineers can be onboarded in minutes rather than days. The agent reads the logs of the setup script and provides a success/failure report with suggested resolutions.


--------------------------------------------------------------------------------


Key Quotes

* "You don't need to tell an expert to learn; it's in their DNA."
* "The code is the true source of truth... but that does not mean auxiliary documents and mental models are not valuable."
* "You want to be building the agentic layer of your codebase. Don't work on the application anymore; work on the agents that build the application for you."
* "There is no codebase I create that does not have meta-agentics."
* "The best AI developers aren't just prompt engineers; they understand how software and LLMs work under the hood."
