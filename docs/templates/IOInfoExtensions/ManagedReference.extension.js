var enhancedExample = require('./ManagedReference.enhancedExample.js');

exports.postTransform = function (model) {
    if (enhancedExample && enhancedExample.postTransform) {
        model = enhancedExample.postTransform(model);
    }

    return model;
}
