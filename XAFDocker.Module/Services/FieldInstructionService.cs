using DevExpress.ExpressApp;
using XAFDocker.Module.BusinessObjects;

namespace XAFDocker.Module.Services
{
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
            try
            {
                var instructions = objectSpace.GetObjectsQuery<FieldInstruction>()
                    .Where(i => i.IsEnabled)
                    .ToDictionary(
                        i => $"{i.BusinessObjectType}.{i.PropertyName}",
                        i => i.InstructionText
                    );
                instructionCache = instructions;
            }
            catch (Exception)
            {
                // If database query fails, initialize empty cache
                instructionCache = new Dictionary<string, string>();
            }
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
}
