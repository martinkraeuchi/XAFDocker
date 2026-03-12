using DevExpress.ExpressApp;
using DevExpress.ExpressApp.Blazor;
using DevExpress.Persistent.Base;
using Microsoft.JSInterop;
using XAFDocker.Module.Services;

namespace XAFDocker.Blazor.Server.Controllers
{
    public class FieldInstructionBlazorViewController : ViewController<DetailView>
    {
        private FieldInstructionService instructionService;
        private IJSRuntime jsRuntime;
        private DotNetObjectReference<FieldInstructionBlazorViewController> dotNetRef;

        public FieldInstructionBlazorViewController()
        {
            TargetViewType = ViewType.DetailView;
        }

        protected override void OnActivated()
        {
            base.OnActivated();

            try
            {
                instructionService = new FieldInstructionService(ObjectSpace);

                // Get JSRuntime from the Blazor application
                if (Application is BlazorApplication blazorApp)
                {
                    jsRuntime = blazorApp.ServiceProvider.GetService(typeof(IJSRuntime)) as IJSRuntime;

                    if (jsRuntime != null)
                    {
                        // Create a reference to this controller that JavaScript can call
                        dotNetRef = DotNetObjectReference.Create(this);

                        // Attach focus handlers after the view is rendered
                        _ = AttachFocusHandlers();
                    }
                }
            }
            catch (Exception)
            {
                // Fail silently - instructions are helpful but not critical
            }
        }

        private async Task AttachFocusHandlers()
        {
            try
            {
                // Wait a bit for the view to fully render
                await Task.Delay(300);

                // Call JavaScript to attach focus event handlers using event delegation
                await jsRuntime.InvokeVoidAsync("fieldInstructions.attachFocusHandlers", dotNetRef);
            }
            catch (Exception ex)
            {
                // Log the error for debugging
                System.Diagnostics.Debug.WriteLine($"Failed to attach focus handlers: {ex.Message}");
            }
        }

        [JSInvokable]
        public void OnFieldFocused(string propertyName)
        {
            try
            {
                // Clean up the property name (remove suffixes like _I)
                if (propertyName.Contains("_"))
                {
                    propertyName = propertyName.Split('_')[0];
                }

                string objectType = View?.ObjectTypeInfo?.Type?.Name;

                if (string.IsNullOrEmpty(objectType))
                {
                    return;
                }

                string instruction = instructionService?.GetInstruction(objectType, propertyName);

                if (!string.IsNullOrEmpty(instruction))
                {
                    // Show instruction every time the field is focused
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
                    5000,
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
                // Detach JavaScript event handlers
                if (jsRuntime != null)
                {
                    _ = jsRuntime.InvokeVoidAsync("fieldInstructions.detach");
                }

                // Dispose of the .NET object reference
                dotNetRef?.Dispose();
                dotNetRef = null;
            }
            catch (Exception)
            {
                // Fail silently - instructions are helpful but not critical
            }

            base.OnDeactivated();
        }
    }
}
