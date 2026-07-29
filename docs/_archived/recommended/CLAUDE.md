# Mealvana Endurance Documentation Standards

## Document Classification Definitions

### Architecture Design Documents
**Purpose:** Describe the overall system structure, component relationships, and design decisions

**Should Include:**
- Overall system architecture diagrams and component relationships
- Technology selection and architectural decision rationale
- Data flow and system boundaries
- Module division and responsibility allocation
- Key architectural patterns and principles

**Strictly Prohibited:**
- Specific code implementations
- Detailed API definitions
- Specific database field designs
- External tool usage tutorials
- Coding standards and naming conventions
- Specific development workflows

### Technical Design Documents
**Purpose:** Describe technical solution design approaches and key technical decisions

**Should Include:**
- Technical solution choices and comparisons
- Technical considerations in system design
- Design approaches for key technical components
- Technical risks and solutions
- Performance and security considerations
- Technical constraints and limitations

**Strictly Prohibited:**
- Specific code implementations (including class definitions, method signatures, etc.)
- Detailed configuration file contents
- Specific installation and deployment steps
- External tool usage manuals
- Detailed development tutorials

## Design vs Implementation Strict Distinction

### Design
- **Conceptual Level:** Explains "what to do" and "why to do it this way"
- **Abstract Description:** Uses text, diagrams, flowcharts for description
- **Decision-Oriented:** Focus on design decisions and rationale
- **Technology-Agnostic:** Avoid specific technology details as much as possible

### Implementation
- **Execution Level:** Explains "how to do it specifically"
- **Code Level:** Contains specific code, configurations, commands
- **Operation-Oriented:** Focus on specific operational steps
- **Technology-Specific:** Involves detailed usage of specific technologies

## Documentation Reference Standards

### Path Reference Requirements
- **Must use relative paths**, such as: `../requirements/project_requirements.md`
- **Prohibited to use absolute paths**, such as: `/Users/xxx/project/docs/...`
- **Purpose:** Ensure document portability across different machines and environments

### Source Document Annotation
Each organized document must include at the end:
```
## Source Reference
Based on: relative_path_to_original_document
```

## Document Quality Standards

1. **Content Accuracy:** Strictly follow original document content, no additions, deletions, or rewrites
2. **Classification Accuracy:** Classify based on the actual content nature of documents, not original directory structure
3. **Translation Accuracy:** Chinese translation accurately reflects English original meaning, maintain technical term consistency
4. **Reference Integrity:** All references and links use relative paths, ensuring cross-environment usability

## Document Synchronization Requirements

**Critical Rule:** When optimizing any document in the `/docs/` directory, the corresponding Chinese document must be synchronously updated.

### Synchronization Standards:
1. **Content Consistency:** English and Chinese versions must contain identical information
2. **Structure Consistency:** Maintain identical section headings and organization
3. **Update Timing:** Chinese translation must be updated immediately after English version changes
4. **Quality Standards:** Chinese version must meet the same quality standards as English version

### Implementation Process:
- After updating any `.md` file, immediately update corresponding `_zh.md` file
- Ensure translation accuracy while maintaining technical terminology consistency
- Verify both versions follow the same document classification standards
- Update source references in both language versions

## Prohibited Items

1. **Prohibited to include code in design documents**
2. **Prohibited to create new content**, only organize and translate existing content
3. **Prohibited to output implementation documents**, only output design documents
4. **Prohibited to treat external tool tutorials as architecture or technical design**
5. **Prohibited to mix coding standards into architectural design**
6. **Prohibited to update English documents without synchronizing Chinese versions**

This standard ensures the professionalism, accuracy, and maintainability of documentation across both language versions.