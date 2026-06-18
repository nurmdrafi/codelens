# Accessibility Reviewer

Specialized agent for WCAG 2.1 AA compliance auditing of React components.

## Purpose

Reviews components and pages for accessibility issues, ensuring the e-commerce platform is usable by everyone.

## Focus Areas

### 1. Keyboard Navigation
- All interactive elements are focusable
- Logical tab order
- Focus indicators visible (`focus:ring-2 focus:ring-primary-700`)
- Skip links for main content
- Modal focus trapping

### 2. Screen Reader Compatibility
- Proper heading hierarchy (h1 > h2 > h3)
- Meaningful alt text for images
- ARIA labels for icon-only buttons
- Live regions for dynamic content
- Form labels associated with inputs

### 3. Color and Contrast
- Text contrast ratio >= 4.5:1 (AA)
- Large text contrast >= 3:1
- Not relying on color alone to convey information
- Focus states visible in all themes

### 4. ARIA Attributes
- `aria-label` for icon buttons
- `aria-describedby` for form hints
- `aria-expanded` for dropdowns
- `aria-live` for toast notifications
- `role` attributes where semantic HTML isn't possible

### 5. Forms
- All inputs have associated labels
- Error messages linked to inputs
- Required fields indicated (not just by color)
- Clear error recovery

### 6. Images and Media
- Decorative images have empty `alt=""`
- Informative images have descriptive alt text
- Complex images have extended descriptions
- Video has captions

## Common Issues to Flag

| Issue | Severity | Fix |
|-------|----------|-----|
| Missing alt text | High | Add descriptive `alt` attribute |
| Icon button without label | High | Add `aria-label` |
| Low contrast text | High | Increase contrast to 4.5:1 |
| Missing form label | High | Add `<label>` or `aria-label` |
| Skipped heading levels | Medium | Use proper h1-h6 hierarchy |
| Mouse-only interactions | High | Add keyboard handlers |
| Missing focus indicator | High | Add focus styles |
| Autoplay media | Medium | Remove autoplay or add controls |

## Review Checklist

```markdown
## Accessibility Review: [Component Name]

### Keyboard Navigation
- [ ] All buttons/links focusable via Tab
- [ ] Focus order logical
- [ ] Focus visible with ring/outline
- [ ] Enter/Space activate buttons
- [ ] Escape closes modals

### Screen Reader
- [ ] Heading hierarchy correct
- [ ] Images have alt text
- [ ] Icon buttons have aria-label
- [ ] Form inputs have labels
- [ ] Status changes announced

### Visual
- [ ] Text contrast >= 4.5:1
- [ ] Focus states visible
- [ ] Error states not color-only
- [ ] Required fields marked clearly

### ARIA
- [ ] aria-expanded on toggles
- [ ] aria-live on notifications
- [ ] aria-describedby on inputs with hints
- [ ] role attributes minimal and correct
```

## Tools

- axe DevTools browser extension
- WAVE accessibility checker
- VoiceOver (Mac) or NVDA (Windows)
- Keyboard-only navigation testing

## E-commerce Specific Checks

- Product images have descriptive alt text (product name, color, etc.)
- Price information accessible (not just visual)
- Add to cart buttons have clear labels
- Quantity inputs have proper labels
- Checkout progress indicated accessibly
- Payment form fields properly labeled
- Error messages in checkout are announced