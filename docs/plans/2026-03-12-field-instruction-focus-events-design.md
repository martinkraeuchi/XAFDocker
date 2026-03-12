# Field Instruction Focus Events - Design Document

**Date:** 2026-03-12
**Status:** Approved for Implementation
**Target:** XAF Blazor Server Application

## Overview

Implement a system to display contextual help instructions when users focus on editor controls in XAF DetailViews. Instructions are stored in the database and displayed as toast notifications when fields receive focus (mouse or keyboard).

## Requirements

### Functional Requirements
- Intercept focus events on editor controls (text, date, numeric, boolean, lookup, memo)
- Display field-specific instructions stored in database
- Support both mouse and keyboard focus
- Platform-agnostic controller design (works across XAF platforms)
- Instructions managed by administrators at runtime (no code deployment needed)

### Non-Functional Requirements
- No noticeable performance impact
- Graceful degradation (missing instructions don't break functionality)
- Memory-efficient with proper event cleanup
- Cache instructions to minimize database queries

## Architecture

### Component Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      DetailView Opens                        │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│          FieldInstructionViewController                      │
│  - OnActivated: Subscribe to all PropertyEditors            │
│  - ControlCreated: Handle delayed initialization            │
│  - OnDeactivated: Cleanup event handlers                    │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│           FieldInstructionService (Cache)                    │
│  - LoadInstructions: Query database once                    │
│  - GetInstruction: O(1) dictionary lookup                   │
│  - RefreshCache: Manual cache invalidation                  │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│         FieldInstruction Business Object                     │
│  - BusinessObjectType: "Contact"                            │
│  - PropertyName: "Email"                                     │
│  - InstructionText: "Enter customer's email address"        │
│  - IsEnabled: true/false                                     │
└─────────────────────────────────────────────────────────────┘
```

### User Interaction Flow

```
1. User opens Contact DetailView
   ↓
2. Controller activates and loads instruction cache
   ↓
3. For each PropertyEditor:
   - Check if instruction exists
   - Subscribe to GotFocus event
   ↓
4. User tabs to Email field (or clicks)
   ↓
5. GotFocus event fires
   ↓
6. Controller retrieves instruction from cache
   ↓
7. Display toast notification with instruction text
   ↓
8. Auto-dismiss after 3 seconds
```

## Database Schema

### FieldInstruction Business Object

**Location:** `XAFDocker.Module/BusinessObjects/FieldInstruction.cs`

```csharp
[DefaultClassOptions]
public class FieldInstruction : BaseObject
{
    public virtual string BusinessObjectType { get; set; }
    public virtual string PropertyName { get; set; }

    [FieldSize(FieldSizeAttribute.Unlimited)]
    public virtual string InstructionText { get; set; }

    public virtual bool IsEnabled { get; set; }
}
```

**Fields:**
- `BusinessObjectType` - Simple class name (e.g., "Contact", not full namespace)
- `PropertyName` - C# property name (e.g., "Email")
- `InstructionText` - User-facing help message (unlimited length)
- `IsEnabled` - Toggle instructions without deleting

**Indexes:**
- Composite unique index on (BusinessObjectType, PropertyName)
- Ensures one instruction per field

**DbContext Configuration:**
```csharp
modelBuilder.Entity<FieldInstruction>()
    .HasIndex(f => new { f.BusinessObjectType, f.PropertyName })
    .IsUnique();
```

## Service Layer

### FieldInstructionService

**Location:** `XAFDocker.Module/Services/FieldInstructionService.cs`

```csharp
public class FieldInstructionService
{
    private readonly IObjectSpace objectSpace;
    private Dictionary<string, string> instructionCache;

    public FieldInstructionService(IObjectSpace objectSpace)
    {
        this.objectSpace = objectSpace;
        LoadInstructions();
    }

    private void LoadInstructions()
    {
        var instructions = objectSpace.GetObjectsQuery<FieldInstruction>()
            .Where(i => i.IsEnabled)
            .ToDictionary(
                i => $"{i.BusinessObjectType}.{i.PropertyName}",
                i => i.InstructionText
            );
        instructionCache = instructions;
    }

    public string GetInstruction(string businessObjectType, string propertyName)
    {
        string key = $"{businessObjectType}.{propertyName}";
        return instructionCache.TryGetValue(key, out string instruction)
            ? instruction
            : null;
    }

    public void RefreshCache()
    {
        LoadInstructions();
    }
}
```

**Key Design Decisions:**
- In-memory dictionary cache for O(1) lookups
- Load once per ObjectSpace lifetime (per view)
- Only enabled instructions cached
- Returns null for missing instructions (no popup shown)
- Manual refresh method for future enhancements

**Performance:**
- Single database query per view activation
- No queries during focus events
- Memory footprint: ~100 bytes per instruction

## Controller Implementation

### FieldInstructionViewController

**Location:** `XAFDocker.Module/Controllers/FieldInstructionViewController.cs`

```csharp
public class FieldInstructionViewController : ViewController<DetailView>
{
    private FieldInstructionService instructionService;
    private Dictionary<PropertyEditor, EventHandler> focusHandlers;

    public FieldInstructionViewController()
    {
        focusHandlers = new Dictionary<PropertyEditor, EventHandler>();
    }

    protected override void OnActivated()
    {
        base.OnActivated();
        instructionService = new FieldInstructionService(ObjectSpace);

        foreach (PropertyEditor editor in View.GetItems<PropertyEditor>())
        {
            if (editor.Control != null)
            {
                SubscribeToFocusEvent(editor);
            }
            else
            {
                editor.ControlCreated += Editor_ControlCreated;
            }
        }
    }

    private void Editor_ControlCreated(object sender, EventArgs e)
    {
        PropertyEditor editor = (PropertyEditor)sender;
        SubscribeToFocusEvent(editor);
    }

    private void SubscribeToFocusEvent(PropertyEditor editor)
    {
        try
        {
            string objectType = View.ObjectTypeInfo.Type.Name;
            string propertyName = editor.PropertyName;

            string instruction = instructionService.GetInstruction(objectType, propertyName);
            if (string.IsNullOrEmpty(instruction))
                return;

            var control = editor.Control;
            if (control == null) return;

            // Blazor DevExpress controls
            if (control is DxTextBoxBase textBox)
            {
                EventHandler handler = (s, e) => ShowInstruction(instruction);
                textBox.GotFocus += handler;
                focusHandlers[editor] = handler;
            }
            else if (control is DxDateEdit<DateTime> dateEdit)
            {
                EventHandler handler = (s, e) => ShowInstruction(instruction);
                dateEdit.GotFocus += handler;
                focusHandlers[editor] = handler;
            }
            // Extensible: Add more control types as needed
        }
        catch (Exception ex)
        {
            Tracing.LogError($"FieldInstructionViewController: {ex.Message}");
        }
    }

    private void ShowInstruction(string instructionText)
    {
        try
        {
            Application.ShowViewStrategy.ShowMessage(
                instructionText,
                InformationType.Info,
                3000,
                InformationPosition.Top
            );
        }
        catch (Exception ex)
        {
            Tracing.LogError($"Failed to show instruction: {ex.Message}");
        }
    }

    protected override void OnDeactivated()
    {
        foreach (var kvp in focusHandlers)
        {
            var editor = kvp.Key;
            var handler = kvp.Value;

            if (editor.Control is DxTextBoxBase textBox)
                textBox.GotFocus -= handler;
            else if (editor.Control is DxDateEdit<DateTime> dateEdit)
                dateEdit.GotFocus -= handler;
            // Unsubscribe for all subscribed types
        }
        focusHandlers.Clear();
        base.OnDeactivated();
    }
}
```

**Key Design Decisions:**
- Inherits `ViewController<DetailView>` - only activates on edit forms
- Handles immediate and delayed control creation (ControlCreated event)
- Tracks handlers for proper cleanup (prevents memory leaks)
- Fail-silent error handling (logs but doesn't throw)
- Extensible control type support

## Platform-Specific Implementation

### Phase 1: Blazor Server (Initial Implementation)

**Supported Editor Types:**
- Text: `DxTextBox`, `DxMemo` (inherits from DxTextBoxBase)
- Date/Time: `DxDateEdit<DateTime>`, `DxDateEdit<DateOnly>`
- Numeric: `DxSpinEdit<int>`, `DxSpinEdit<decimal>`
- Boolean: `DxCheckBox`
- Lookup: `DxComboBox<T>`

**Focus Event:** All DevExpress Blazor editors support `GotFocus` event

### Phase 2: WinForms (Future Enhancement)

If WinForms platform needed:
- Text: Cast to `TextEdit`
- Date: Cast to `DateEdit`
- Use similar pattern with different control types
- Add conditional compilation or runtime platform detection

## Display Mechanism

### Toast Notification (Phase 1)

**Implementation:**
```csharp
Application.ShowViewStrategy.ShowMessage(
    instructionText,
    InformationType.Info,
    3000, // 3 seconds
    InformationPosition.Top
);
```

**Characteristics:**
- Platform-agnostic XAF API
- Toast-style notification at top of screen
- Auto-dismisses after 3 seconds
- Non-intrusive (doesn't block UI)
- Minimal implementation effort

### Custom Popover (Phase 2 - Future Enhancement)

If richer display needed:
- Position near focused field
- Custom styling (colors, icons, formatting)
- Stay visible while field has focus
- Dismiss on blur or explicit close
- Requires Blazor component development

## Error Handling

### Principles
- **Fail silently** - Instructions are helpful but not critical
- **Log errors** - Use XAF Tracing for debugging
- **Graceful degradation** - Missing instructions don't break app
- **Null safety** - Check all objects before use

### Error Scenarios
1. **Missing instruction** → No popup shown (normal behavior)
2. **Database query fails** → Empty cache, no instructions shown
3. **Unknown control type** → Silently skip, log for future support
4. **ShowMessage throws** → Log error, continue execution
5. **Focus event exception** → Log error, other editors still work

## Testing Strategy

### Phase 1: Basic Functionality
1. Create FieldInstruction records for Contact fields
   - FirstName: "Enter the contact's first name"
   - Email: "Enter a valid email address (required)"
   - Phone: "Format: +1-555-123-4567"
2. Open Contact DetailView
3. Tab through fields → Verify instructions appear
4. Click fields with mouse → Verify instructions appear
5. Fields without instructions → No popup (expected)
6. Set IsEnabled=false → No instruction shown

### Phase 2: Edge Cases
- Very long instruction text (500+ characters)
- Special characters and line breaks in text
- Rapid focus changes (tab quickly through fields)
- Multiple DetailViews open simultaneously
- Edit instruction while view is open (won't update until refresh)

### Phase 3: Performance
- DetailView with 50+ fields
- Verify single database query on view open
- Check no queries during focus events (cache working)
- Memory usage with 10+ open views
- Response time < 100ms from focus to display

### Phase 4: Platform Support
- Test on Blazor Server (primary)
- Test supported editor types:
  - String properties → DxTextBox
  - DateTime properties → DxDateEdit
  - Int/Decimal properties → DxSpinEdit
  - Boolean properties → DxCheckBox
  - Lookup properties → DxComboBox

## Implementation Plan

### Task Breakdown

1. **Create FieldInstruction Business Object**
   - Create class in BusinessObjects folder
   - Add to DbContext as DbSet
   - Configure unique index in OnModelCreating
   - Create migration
   - Update database

2. **Create FieldInstructionService**
   - Create Services folder if not exists
   - Implement service with caching
   - Add unit tests (optional)

3. **Create FieldInstructionViewController**
   - Create Controllers folder if not exists
   - Implement base controller with focus handling
   - Start with text and date editors
   - Add error handling and logging

4. **Database Seeding**
   - Add sample instructions in Updater.cs
   - Create instructions for Contact fields
   - Test data for validation

5. **Manual Testing**
   - Run application
   - Test focus events on Contact DetailView
   - Verify instructions display correctly
   - Test edge cases

6. **Documentation**
   - Update CLAUDE.md with new feature
   - Add administrator guide for managing instructions
   - Document supported editor types

7. **Expand Editor Support** (Future)
   - Add numeric editors
   - Add boolean editors
   - Add lookup editors
   - Add memo editors

## Future Enhancements

### Phase 2 Features
- Custom popover positioning near focused field
- Rich text formatting in instructions (bold, links)
- Multilingual instruction support
- Cache invalidation on instruction updates
- Session-based "don't show again" for same field

### Phase 3 Features
- Instruction categories (hint, warning, requirement)
- Conditional instructions based on business logic
- Video or image attachments
- Usage analytics (which fields need more help)
- AI-powered instruction suggestions

## References

- [PropertyEditor Class Documentation](https://docs.devexpress.com/eXpressAppFramework/DevExpress.ExpressApp.Editors.PropertyEditor)
- [Customize a Built-in Property Editor (Blazor)](https://docs.devexpress.com/eXpressAppFramework/402188/ui-construction/view-items-and-property-editors/property-editors/customize-a-built-in-property-editor-blazor)
- [Ways to Access UI Elements and Their Controls](https://docs.devexpress.com/eXpressAppFramework/120092/ui-construction/ways-to-access-ui-elements-and-their-controls/ways-to-access-ui-elements-and-their-controls)
- [Dennis Garavsky's Blog: Traverse and Customize XAF View Items](https://dennisgaravsky.blogspot.com/2014/01/how-to-traverse-and-customize-xaf-view.html)

## Approval

- **Design Status:** ✅ Approved
- **Ready for Implementation:** Yes
- **Next Steps:** Create implementation plan and begin development