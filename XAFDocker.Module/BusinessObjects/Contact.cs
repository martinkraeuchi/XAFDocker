using DevExpress.ExpressApp.DC;
using DevExpress.Persistent.Base;
using DevExpress.Persistent.BaseImpl.EF;
using DevExpress.Persistent.Validation;
using System.ComponentModel;

namespace XAFDocker.Module.BusinessObjects
{
    [DefaultClassOptions]
    [DefaultProperty(nameof(FullName))]
    public class Contact : BaseObject
    {
        public virtual string FirstName { get; set; }

        public virtual string LastName { get; set; }

        [RuleRequiredField(DefaultContexts.Save)]
        public virtual string Email { get; set; }

        public virtual string Phone { get; set; }

        public virtual string Company { get; set; }

        [FieldSize(FieldSizeAttribute.Unlimited)]
        public virtual string Notes { get; set; }

        [VisibleInListView(false)]
        public string FullName
        {
            get { return $"{FirstName} {LastName}".Trim(); }
        }
    }
}
