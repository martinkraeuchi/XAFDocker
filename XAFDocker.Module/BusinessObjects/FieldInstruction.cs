using DevExpress.ExpressApp.DC;
using DevExpress.Persistent.Base;
using DevExpress.Persistent.BaseImpl.EF;
using DevExpress.Persistent.Validation;
using System.ComponentModel;

namespace XAFDocker.Module.BusinessObjects
{
    [DefaultClassOptions]
    [DefaultProperty(nameof(PropertyName))]
    public class FieldInstruction : BaseObject
    {
        [RuleRequiredField(DefaultContexts.Save)]
        public virtual string BusinessObjectType { get; set; }

        [RuleRequiredField(DefaultContexts.Save)]
        public virtual string PropertyName { get; set; }

        [FieldSize(FieldSizeAttribute.Unlimited)]
        [RuleRequiredField(DefaultContexts.Save)]
        public virtual string InstructionText { get; set; }

        public virtual bool IsEnabled { get; set; } = true;
    }
}
