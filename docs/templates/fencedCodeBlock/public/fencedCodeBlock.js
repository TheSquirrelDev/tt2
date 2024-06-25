export default {
    start: isDocfxInitalized
}

/**
 * Wait for DocFX to be initialized. It's initalization writes the code copy
 * button into the DOM. If we format the code blocks to be fenced prior to this
 * we still need to come back and remove the button. So just wait for it then
 * recreate the DOM to be fenced.
 */
function isDocfxInitalized() {
    if(window.docfx.ready !== true) {
       window.setTimeout(isDocfxInitalized, 250); /* this checks the flag every 100 milliseconds*/
       console.log('FencedCodeBlock: Waiting for DocFX to be initialized...');
    } else {
        console.log('FencedCodeBlock: DocFX is initialized. Fencing code blocks.');
        renderFencedCode();
    }
}

/**
 * Render fenced code.
 */
function renderFencedCode() {
    var codeBlocks = document.querySelectorAll('pre>code:not(.fc>pre>code)');
    console.log('FencedCodeBlock: Found ' + codeBlocks.length + ' code blocks to fence.');

    for (var i = 0; i < codeBlocks.length; i++) {
        var code = codeBlocks[i];
        if (code.textContent.trim().length === 0) {
          return
        }

        const displayLanguage = getDisplayLanguage(code.className);
        const fencedCode = createFencedCodeBlock(code, displayLanguage);
        enableCopyButton(fencedCode.querySelector('.fc-copy'));

        code.parentElement.replaceWith(fencedCode);
    }
}

function getDisplayLanguage(classes)
{
    var language = classes.split(' ').find(c => c.startsWith('lang-')).replace('lang-', '') ?? 'plaintext';

    switch (language.toLowerCase())
    {
        case 'csharp':
            return 'C#';
        case 'powershell':
            return 'PowerShell';
        case 'xml':
            return 'XML';
        case 'html':
            return 'HTML';
        case 'css':
            return 'CSS';
        case 'javascript':
            return 'JavaScript';
        case 'typescript':
            return 'TypeScript';
        case 'java':
            return 'Java';
        case 'python':
            return 'Python';
        case 'plaintext':
            return 'Text';
        default:
            return language;
    }
}

function createFencedCodeBlock(codeNode, language) {
    var div = document.createElement('div');
    div.innerHTML = `<div class="fc">
        <div class="fc-header">
            <span class="language">${language}</span>
            <button class="fc-copy position-relative" type="button">
                <i class="bi bi-copy"></i>
                <span>Copy</span>
                <div class="successful-copy-alert position-absolute is-transparent" aria-hidden="true">
                    <i class="bi bi-check-lg"></i>
                </div>
            </button>
        </div>
        <pre>
            ${codeNode.outerHTML}
        </pre>
    </div>`;

    // Change this to div.childNodes to support multiple top-level nodes.
    return div.firstChild;
}

function enableCopyButton(button) {
    button.addEventListener('click', function(event) {
        var fc = event.currentTarget.parentElement.parentElement;

        if (!fc.classList.contains('fc')) {
            console.log('FencedCodeBlock: Copy button not found in expected parent element.');
        }

        var code = fc.querySelector('pre>code');
        var alert = fc.querySelector('.successful-copy-alert');

        navigator.clipboard.writeText(code.textContent).then(() => {
            alert.classList.remove('is-transparent');
            setTimeout(() => {
                alert.classList.add('is-transparent');
            }, 1250);
        }).catch(err => {
            console.error('Failed to copy text: ', err);
        });
    });
}
