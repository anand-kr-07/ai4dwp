# DWP Personal AI Usage Charter

## Purpose
This charter defines how I will use public AI assistants safely and effectively during DWP desktop and endpoint support work. It is a personal operating standard for day-to-day engineering and service desk tasks.

## Scope
Applies to public LLM tools that are not DWP-managed secure AI environments.

## 1. Appropriate tasks for public LLM help
I may use public AI for low-risk, non-sensitive support activities such as:
- Drafting troubleshooting checklists for common endpoint issues (slow device, app launch failure, profile issues).
- Explaining PowerShell commands and Windows settings in plain language.
- Generating first-draft scripts with placeholder values for routine local tasks.
- Creating command-line syntax examples, regex patterns, and log parsing approaches using synthetic sample data.
- Drafting user communications, ticket updates, and triage templates with no personal or internal sensitive data.
- Producing step-by-step test plans for desktop fixes before execution.

## 2. Tasks not appropriate for public LLMs
I will not use public AI for:
- Any prompt containing end-user personal data, credentials, or security answers.
- Any internal-only technical detail that could expose DWP systems, controls, architecture, vulnerabilities, or active incidents.
- Uploading logs, screenshots, emails, or ticket extracts that include identifiable users, device IDs tied to individuals, or sensitive operational context.
- Asking for or validating production change actions without internal review and approved change process.
- Decisions that require policy, legal, HR, fraud, or security authority.

## 3. Data-handling rule (PII and credentials)
Hard rule: no end-user PII and no credentials in any public AI prompt, ever.
- Never include names, email addresses, phone numbers, NI numbers, home addresses, usernames, passwords, MFA codes, tokens, session cookies, or recovery answers.
- Never paste raw tickets or logs directly. Redact first and replace with neutral placeholders (for example: USER_A, DEVICE_X, DOMAIN_Y).
- If a prompt needs context, provide only the minimum technical facts required, in anonymized form.
- If I cannot confidently anonymize data, I do not use a public AI tool for that task.

## 4. Personal generate then verify rule (scripts and system changes)
I will treat AI output as a draft, not an instruction to run.
- Generate: ask AI for a proposed script or change plan using placeholders and clear assumptions.
- Review: read line by line; remove unsafe commands, broad wildcards, destructive actions, and unnecessary privilege.
- Validate: test in a safe environment or non-production endpoint first.
- Check controls: confirm rollback steps, logging, and least-privilege execution.
- Execute: run only after peer sense-check (where available) and within change/process rules.
- Verify: confirm expected outcome, check for side effects, and record what was run and why in the ticket.

## Personal accountability statement
I remain accountable for every command executed, every change made, and every data item shared. AI can assist my speed, but not replace my judgement, policy compliance, or verification duties.
