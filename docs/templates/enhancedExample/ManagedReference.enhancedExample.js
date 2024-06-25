// Either rename this file to ManagedReference.extension.js or in your ManagedReference.extension.js file, load and call this file.
//
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// ** in docs/templates/ManagedReference.extension.js **
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// var enhancedExample = require('./ManagedReference.enhancedExample.js');
//
// exports.postTransform = function (model) {
//     if (enhancedExample && enhancedExample.postTransform) {
//         model = enhancedExample.postTransform(model);
//     }
//
//     return model;
// }
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

const summaryRegex = /(?<xmlSummary><summary>(?<summary>.+)<\/summary>)/si;
const remarksRegex = /(?<xmlRemarks><remarks>(?<remarks>.+)<\/remarks>)/si;
const codeRegex = /(?<xmlCode><pre><code.*?class="lang-(?<language>[^"]+)[^>]*>(?<code>[^<]+)<\/code><\/pre>)/gi;

exports.postTransform  = function (model) {
    if (!model) return null;
    if (model.type !== 'method' || !model.children || !model.children.length) return model;

    var children = model.children;
    for (var i = 0; i < children.length; i++) {
        for (var j = 0; j < children[i].children.length; j++) {
            var method = children[i].children[j];
            if (!method.example) continue;

            var examples = method.example;
            var enhancedExamples = [];
            for (var k = 0; k < examples.length; k++) {
                var example = examples[k];
                var enhancedExample = {
                    methodId: method.id,
                    index: k,
                    summary: null,
                    remarks: null,
                    codeBlocks: []
                }

                var summarySearch = summaryRegex.exec(example);
                var remarksSearch = remarksRegex.exec(example);
                var remainingText = example;

                if (summarySearch && summarySearch.groups) {
                    enhancedExample.summary = summarySearch.groups.summary.trim();
                    remainingText = remainingText.replace(summarySearch.groups.xmlSummary, '');
                }

                if (remarksSearch && remarksSearch.groups) {
                    enhancedExample.remarks = remarksSearch.groups.remarks.trim();
                    remainingText = remainingText.replace(remarksSearch.groups.xmlRemarks, '');
                }

                let codeSearch;
                var blockCount = 0;
                while((codeSearch = codeRegex.exec(example)) !== null) {
                    if (!codeSearch.groups || !codeSearch.groups.language) {
                        console.warn(`Code block ${blockCount + 1} in example ${k + 1} of method ${method.id} does not have a language specified. It will be skipped.`);
                        continue;
                    }

                    if (enhancedExample.codeBlocks.find(cb => cb.language === codeSearch.groups.language)) {
                        console.warn(`Code block ${blockCount + 1} in example ${k + 1} of method ${method.id} has a duplicate language. It will be skipped.`);
                    }

                    enhancedExample.codeBlocks.push({
                        methodId: method.id,
                        exampleIndex: enhancedExample.index,
                        codeIndex: blockCount,
                        code: codeSearch.groups.xmlCode.trim(),
                        language: codeSearch.groups.language,
                        displayLanguage: toLanguageDisplay(codeSearch.groups.language)
                    });

                    blockCount++;
                    remainingText = remainingText.replace(codeSearch.groups.xmlCode, '');
                }

                remainingText = remainingText.replace(/(?:\r\n|\r|\n)/g, '').trim();
                if (remainingText && !enhancedExample.summary) {
                    enhancedExample.summary = remainingText;
                }

                enhancedExamples.push(enhancedExample);
            }

            method.enhancedExample = enhancedExamples;
        }
    }

    return model;
}

function toLanguageDisplay(language) {
    if (!language) return "";

    switch(language.toLowerCase()) {
        case 'powershell': return 'PowerShell';
        case 'csharp': return 'C#';
        default: return language;
    }
}
