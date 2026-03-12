using DevExpress.Data.Filtering;
using DevExpress.ExpressApp;
using DevExpress.ExpressApp.EF;
using DevExpress.ExpressApp.Updating;
using DevExpress.Persistent.Base;
using DevExpress.Persistent.BaseImpl.EF;
using Microsoft.Extensions.DependencyInjection;

namespace XAFDocker.Module.DatabaseUpdate
{
    // For more typical usage scenarios, be sure to check out https://docs.devexpress.com/eXpressAppFramework/DevExpress.ExpressApp.Updating.ModuleUpdater
    public class Updater : ModuleUpdater
    {
        public Updater(IObjectSpace objectSpace, Version currentDBVersion) :
            base(objectSpace, currentDBVersion)
        {
        }
        public override void UpdateDatabaseAfterUpdateSchema()
        {
            base.UpdateDatabaseAfterUpdateSchema();

            // Seed sample FieldInstruction records for Contact fields
            CreateFieldInstructionIfNotExists("Contact", "FirstName", "Enter the contact's first name");
            CreateFieldInstructionIfNotExists("Contact", "LastName", "Enter the contact's last name");
            CreateFieldInstructionIfNotExists("Contact", "Email", "Enter a valid email address (required)");
            CreateFieldInstructionIfNotExists("Contact", "Phone", "Enter phone number (e.g., +1-555-123-4567)");
            CreateFieldInstructionIfNotExists("Contact", "Company", "Enter the company name where this contact works");
            CreateFieldInstructionIfNotExists("Contact", "Notes", "Add any additional notes or comments about this contact");

            ObjectSpace.CommitChanges();
        }

        private void CreateFieldInstructionIfNotExists(string businessObjectType, string propertyName, string instructionText)
        {
            var existing = ObjectSpace.GetObjectsQuery<BusinessObjects.FieldInstruction>()
                .FirstOrDefault(f => f.BusinessObjectType == businessObjectType && f.PropertyName == propertyName);

            if (existing == null)
            {
                var instruction = ObjectSpace.CreateObject<BusinessObjects.FieldInstruction>();
                instruction.BusinessObjectType = businessObjectType;
                instruction.PropertyName = propertyName;
                instruction.InstructionText = instructionText;
                instruction.IsEnabled = true;
            }
        }
        public override void UpdateDatabaseBeforeUpdateSchema()
        {
            base.UpdateDatabaseBeforeUpdateSchema();
        }
    }
}
