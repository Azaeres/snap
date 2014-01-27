# Snap

### Action queue and simple constraining tool

## Usage

    var SnapChain = require('snap');
    
    (new SnapChain("Optional name for this chain"))
    
      .snap(function(go) {
        console.log("1st transformation does some stuff");
        this.foo = 4;
        // When done, call `go()`, which causes the chain to proceed to the next link in the chain.
        go();
      })
      
      .snap("An optional description for this link", function(go) {
        console.log("2nd transformation stuff");
        // `this.foo` is still what we set it to in the last transformation.
        console.log(this.foo === 4);
        // Remember to call `go()` when you want to proceed, or the rest of the chain won't run!
        go();
      })
      
      .snap(function(go, index, name, chain) {
        // We can inspect the state of the chain by checking out the arguments passed in.
        // `index` is the link index of the block that is currently running.
        // `name` is the name that is given to the block, if any.
        // `chain` is the actual snap chain object.
        go();
      })
      
      .snap(function(go) {
        // `go()` takes an options argument for integration testing!
        go({
        
          // `gather` (optional) should be a function that gathers some information we're interested in checking, and packages it into an object for inspection.
          // Once a gatherer is set like this, it'll be run between link transitions to gather an updated
          // snapshot of that information for another comparison.
          gather: function(go) {
            go({ 'jquery version':$.fn.jquery });
          },
          
          // `expect` (optional) is an object that will be compared against what the gather function
          // packages up. Values not listed here are not compared. 
          // If there is a difference between what was expected here and what was found, it'll be logged
          // to the console. No error is thrown to avoid blocking execution of the chain.
          expect: { 'jquery version':'2.1.0' }
        });
      })
      
      
      
