# Fam Help Desk

Fam Help Desk is a family-first help desk / ticketing system built as a learning project using a single-table DynamoDB design. This monorepo contains all components for the project:

- **FamTicketsBackend**: Python backend models and logic (Python)
- **FamTicketsInfra**: AWS CDK infrastructure as code (TypeScript)
- **FamTicketsWebsite**: Frontend web application (React)

## Features
- Multi-family support (each family is an isolated help desk)
- Groups and group membership within families
- Queues owned by groups
- Tickets with comments and full auditing
- Single-table DynamoDB design for scalability and efficiency
- Infrastructure as code with AWS CDK
- Modern web frontend

## Architecture Overview
- **Backend**: Contains the database models, API code, and all backend logic for the application.
- **Infrastructure**: Infrastructure as code for deploying and managing all cloud resources.
- **Website**: The frontend web application for users to interact with the system.

## DynamoDB Design Principles
- All items for a family use `pk = FAMILY#{family_id}`
- Hierarchical `sk` values model containment (e.g., `GROUP#{group_id}#MEMBER#{user_id}`)
- Audit records are append-only and immutable
- Timestamps are stored as epoch seconds (int)
- All attribute names use Python-friendly `snake_case`

## Directory Structure
- `FamHelpDeskBackend/` — Python backend models and logic
- `FamHelpDeskInfra/` — AWS CDK infrastructure
- `FamHelpDeskWebsite/` — Web frontend
- `FamHelpDeskiOS/` — iOS native application

## Development

### Code Formatting

**Swift (iOS):**
```bash
# Install SwiftFormat
brew install swiftformat

# Format all Swift files
swiftformat .

# Or use Apple's official formatter
brew install swift-format
swift-format format -i -r .
```

**Python (Backend):**
```bash
# Install Black
pip install black

# Format all Python files
black .
```

**TypeScript/JavaScript (Infrastructure & Website):**
```bash
# Install Prettier
npm install -g prettier

# Format all files
prettier --write .
```
