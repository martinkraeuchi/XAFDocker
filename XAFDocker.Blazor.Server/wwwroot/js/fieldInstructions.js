// Field Instructions Focus Handler
window.fieldInstructions = {
    dotNetHelper: null,

    attachFocusHandlers: function (dotNetHelper) {
        console.log('Attaching field instruction focus handlers...');

        // Store the dotNetHelper for later use
        this.dotNetHelper = dotNetHelper;

        // Use event delegation on the document to catch all focus events
        // This works even for dynamically created elements
        document.removeEventListener('focusin', this.handleFocus);
        document.addEventListener('focusin', this.handleFocus.bind(this));

        console.log('Focus handlers attached using event delegation');
    },

    handleFocus: function(e) {
        // Only handle input, textarea, and select elements
        const target = e.target;
        if (!target.matches('input:not([type="hidden"]), textarea, select, [contenteditable="true"]')) {
            return;
        }

        // Try to find the property name from various attributes
        let propertyName = null;

        // Check the element and its parents for XAF property editor attributes
        let element = target;
        for (let i = 0; i < 15; i++) {
            if (!element) break;

            // Look for data attributes that might contain the property name
            if (element.hasAttribute('data-property-name')) {
                propertyName = element.getAttribute('data-property-name');
                break;
            }

            // Check for XAF-specific class names that contain the property name
            if (element.className && typeof element.className === 'string') {
                const classes = element.className.split(' ');
                for (const cls of classes) {
                    // Look for classes like 'property-FirstName' or 'editor-FirstName'
                    if (cls.startsWith('property-') || cls.startsWith('editor-')) {
                        propertyName = cls.split('-')[1];
                        if (propertyName && propertyName.length > 0) {
                            break;
                        }
                    }
                }
                if (propertyName) break;
            }

            // Check for container with data attributes
            const dataKeys = element.dataset ? Object.keys(element.dataset) : [];
            for (const key of dataKeys) {
                if (key.toLowerCase().includes('property')) {
                    propertyName = element.dataset[key];
                    break;
                }
            }
            if (propertyName) break;

            // Look for aria-label or title that might contain the property name
            if (element.getAttribute('aria-label')) {
                const label = element.getAttribute('aria-label');
                // Property names often appear in labels
                const match = label.match(/\b([A-Z][a-zA-Z]+)\b/);
                if (match) {
                    propertyName = match[1];
                }
            }

            // Check parent element's attributes for hints
            if (element.parentElement) {
                const parentClass = element.parentElement.className;
                if (parentClass && typeof parentClass === 'string') {
                    // Look for XAF view item containers
                    const match = parentClass.match(/ViewItem[_-]([A-Z][a-zA-Z]+)/);
                    if (match) {
                        propertyName = match[1];
                        break;
                    }
                }
            }

            element = element.parentElement;
        }

        // If we still don't have a property name, try to find it from the closest label
        if (!propertyName) {
            // Find closest label element
            let checkElement = target.parentElement;
            for (let i = 0; i < 5; i++) {
                if (!checkElement) break;
                const label = checkElement.querySelector('label');
                if (label && label.textContent) {
                    // Extract text and convert "First Name" -> "FirstName"
                    const text = label.textContent.trim();
                    const words = text.split(/\s+/);

                    // Collect all capitalized words and join them (e.g., "First Name" -> "FirstName")
                    const capitalizedWords = [];
                    for (const word of words) {
                        if (word.length > 1 && word[0] === word[0].toUpperCase()) {
                            const cleanWord = word.replace(/[^a-zA-Z]/g, '');
                            if (cleanWord.length > 0) {
                                capitalizedWords.push(cleanWord);
                            }
                        }
                    }

                    if (capitalizedWords.length > 0) {
                        // Join all words together (e.g., ["First", "Name"] -> "FirstName")
                        propertyName = capitalizedWords.join('');
                        break;
                    }
                }
                checkElement = checkElement.parentElement;
            }
        }

        // Only send if we have a valid-looking property name (not a GUID)
        if (propertyName && this.dotNetHelper) {
            // Skip if it looks like a GUID or random ID
            if (!propertyName.includes('-') && propertyName.length < 50) {
                console.log('Focus detected on property:', propertyName);
                this.dotNetHelper.invokeMethodAsync('OnFieldFocused', propertyName)
                    .catch(err => console.error('Error calling OnFieldFocused:', err));
            } else {
                console.log('Skipping GUID/ID:', propertyName);
            }
        }
    },

    detach: function() {
        console.log('Detaching field instruction focus handlers');
        document.removeEventListener('focusin', this.handleFocus);
        this.dotNetHelper = null;
    }
};
