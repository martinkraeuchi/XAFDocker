using DevExpress.ExpressApp;
using DevExpress.ExpressApp.Editors;
using DevExpress.Persistent.Base;
using XAFDocker.Module.Services;

namespace XAFDocker.Module.Controllers
{
    public class FieldInstructionViewController : ViewController<DetailView>
    {
        private FieldInstructionService instructionService;
        private HashSet<string> instructionsShownForCurrentObject;

        public FieldInstructionViewController()
        {
            instructionsShownForCurrentObject = new HashSet<string>();
        }

        protected override void OnActivated()
        {
            base.OnActivated();

            try
            {
                instructionService = new FieldInstructionService(ObjectSpace);
                instructionsShownForCurrentObject.Clear();

                // Subscribe to all property editors
                foreach (PropertyEditor editor in View.GetItems<PropertyEditor>())
                {
                    SubscribeToEditor(editor);
                }

                // Reset shown instructions when the object changes
                View.CurrentObjectChanged += (s, e) => instructionsShownForCurrentObject.Clear();
            }
            catch (Exception)
            {
                // Fail silently - instructions are helpful but not critical
            }
        }

        private void SubscribeToEditor(PropertyEditor editor)
        {
            try
            {
                string objectType = View.ObjectTypeInfo.Type.Name;
                string propertyName = editor.PropertyName;

                string instruction = instructionService?.GetInstruction(objectType, propertyName);
                if (string.IsNullOrEmpty(instruction))
                    return;

                // Subscribe to multiple events to catch different interaction patterns

                // 1. ValueRead - fires when the editor reads its value from the object
                // This happens on initial display and when focus moves to the field
                EventHandler valueReadHandler = null;
                valueReadHandler = (s, e) =>
                {
                    ShowInstructionOnce(propertyName, instruction);
                };
                editor.ValueRead += valueReadHandler;

                // 2. ControlValueChanged - fires when user changes the value
                EventHandler valueChangedHandler = null;
                valueChangedHandler = (s, e) =>
                {
                    ShowInstructionOnce(propertyName, instruction);
                };
                editor.ControlValueChanged += valueChangedHandler;
            }
            catch (Exception)
            {
                // Fail silently - instructions are helpful but not critical
            }
        }

        private void ShowInstructionOnce(string propertyName, string instruction)
        {
            try
            {
                // Only show each instruction once per object to avoid spam
                if (!instructionsShownForCurrentObject.Contains(propertyName))
                {
                    instructionsShownForCurrentObject.Add(propertyName);
                    ShowInstruction(instruction);
                }
            }
            catch (Exception)
            {
                // Fail silently - instructions are helpful but not critical
            }
        }

        private void ShowInstruction(string instructionText)
        {
            try
            {
                Application?.ShowViewStrategy?.ShowMessage(
                    instructionText,
                    InformationType.Info,
                    3000,
                    InformationPosition.Top
                );
            }
            catch (Exception)
            {
                // Fail silently - instructions are helpful but not critical
            }
        }

        protected override void OnDeactivated()
        {
            try
            {
                instructionsShownForCurrentObject.Clear();
            }
            catch (Exception)
            {
                // Fail silently - instructions are helpful but not critical
            }

            base.OnDeactivated();
        }
    }
}
