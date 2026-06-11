# E-Attend Virtual Team

This project uses specialized AI agents for different aspects of development.

## Available Agents

### 👨‍💼 Product Owner
- **File**: `.github/instructions/product-owner.instructions.md`
- **Specialty**: Feature brainstorming, user stories, prioritization, requirements definition
- **Use when**: Planning features, defining MVP scope, creating acceptance criteria, exploring new ideas

### 🎨 UI/UX Designer
- **File**: `.github/instructions/ui-ux-designer.instructions.md`
- **Specialty**: Visual design, accessibility, layout, animations, Material Design 3
- **Use when**: Designing screens, theming, layout improvements, accessibility fixes

### 👨‍💻 Developer
- **File**: `.github/instructions/developer.instructions.md`
- **Specialty**: Clean architecture, Firebase integration, state management, code quality
- **Use when**: Implementing features, fixing bugs, refactoring, writing business logic

## Suggested Future Agents

| Agent | Purpose |
|-------|---------|
| 🧪 **QA/Tester** | Test plans, edge case coverage, regression testing, bug reports |
| 🔐 **Security & Data** | Firebase security rules, data validation, authentication flows, privacy |
| 📊 **Analytics & Reports** | Dashboard metrics, PDF/CSV export, data visualization, insights |
| 🚀 **DevOps** | CI/CD pipeline, Firebase deployment, monitoring, release management |

## How to Use

In the Copilot CLI interactive mode, use:

```
/agent        # Browse and select available agents
/instructions # Toggle instruction files on/off
/fleet        # Run agents in parallel on the same task
```
