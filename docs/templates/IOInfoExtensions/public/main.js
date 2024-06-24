import enhancedExample from './enhancedExample.js'
import fencedCodeBlock from './fencedCodeBlock.js'

export default {
    start: function() {
        console.log('IOInfoExtensions plugin started');
        enhancedExample.start();
        fencedCodeBlock.start();
    }
}

