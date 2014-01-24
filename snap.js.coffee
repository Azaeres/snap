
#    
# Snap.js
# =======
#
# v2.0
# 
# Snap is a constraining technique. It is a lightweight form of testing that provides
# a straightforward way of making sure the state of our application meets
# our expectations every step of the way.
#
#
# How to use
# ----------
#
#   // Create a chain. The chain name is optional.
#   (new SnapChain('An optional name for this chain'))
#
#
#   // Add a link to the chain by calling `snap()`.
#   .snap(function() {
#
#     // The function that's passed into `snap()` is called a "mutator", because 
#     // its role is to potentially mutate application state.
#
#     // Variables attached to `this` are accessible down the chain.
#     // The only properties that are reserved by the snap chain are `next`, 
#     // `link`, and `name`. Overwriting these reserved properties may 
#     // cause the snap chain to not behave properly.
#     this.stash = 'yay';
#
#     // Each link waits until `this.next()` is called. This can be called 
#     // in an asyncronous callback, in order to 
#     // Pass in an object that has the following optional properties:
#     this.next({
#
#       // `gather`: A function that returns a bundle of state gathered from 
#       // around the system. The state gathered can be anything; it is whatever
#       // we are interested in watching. Call `this.next()` when done 
#       // gathering, and pass in the gathered state snapshot.
#
#       // The gather function is not intended to change application state; its
#       // role is simply to gather it.
#       gather: function() {
#         var snapshot = GatherState();
#         this.next(snapshot);
#       }, 
#
#       // `expect`: An object that looks like what you expect the gathered 
#       // state to look like. If you pass in an empty object, or nothing, 
#       // the link will not run a comparison, causing it to be silent for this 
#       // link.
#       expect: {
#         foo:'bar'
#       }
#     });
#
#   })
#
#   .snap('An optional short description', function() {
#
#     // This is the second link in the chain.
#
#     // The `this` object is the same object for each link mutator in the chain,
#     // so variables you set into it will still be accessible down the chain.
#     snapshot.foo = this.stash;
#
#     // Not passing a `gather` function into `this.next()` just uses the 
#     // last state gatherer you passed into the chain. If you haven't passed 
#     // in a gatherer yet, it just uses the default gatherer, which is a 
#     // simple stub that returns an empty object.
#
#     // Passing an empty object into `this.next()` is effectively the 
#     // same as passing no arguments.
#
#     this.next();
#
#   })
#
#   
# 
#

_ = require 'underscore'
ActionQueue = require 'action-queue'

class SnapChain
  constructor: (name) ->
    @_actionQueue = new ActionQueue()

    # Every link in the chain has a unique index.
    @_index = -1

    _desc = ""
    _desc = name  unless _.isUndefined(name)
    
    # The default state gatherer is an empty stub.
    _stateGatherer = (go) ->
      go()

    @_go = (options) =>
      options = {}  if _.isUndefined(options)
      _stateGatherer = options.gather  unless _.isUndefined(options.gather)
      settings = _.extend(
        gather: _stateGatherer
        expect: {}
      , options)

      # Logs differences to the console.      
      log = (diffs) =>
        if diffs.length > 0
          # Show the description, if we have provided one.
          if _desc isnt ""
            console.info "\n" + _desc
            
            # We'll only bother to show the description once.
            _desc = ""
          
          # This is where we show the link index.
          # Show groups in the console if possible.
          nameStr = ""
          nameStr = " - \"" + @name + "\""  if @name isnt ""
          str = "Snap! Link " + @_index + nameStr
          if _.isFunction(console.group)
            console.group str
          else
            console.error str
          
          # Present what we found right next to what we expected, so 
          # the developer can see the difference.
          d = { found:{}, expected:{} }
          _(diffs).each (diff) =>
            _.extend(d.found, diff.found)
            _.extend(d.expected, diff.expected)

          console.error "   Found: ", d.found, "\n Expected: ", d.expected
          console.groupEnd()  if _.isFunction(console.groupEnd)


      differences = (snapshot, expectation) =>
        # We'll clone the input here so that we see what they looked like
        # at the time they were logged to console, instead of being a live 
        # reference to the object.
        snapshot = _.clone(snapshot)
        expectation = _.clone(expectation)
        
        diffs = []
        _(expectation).each (value, key) =>
          if snapshot[key] != expectation[key]
            expectationProp = {}
            expectationProp[key] = value
            snapshotProp = {}
            snapshotProp[key] = snapshot[key]
            diffs.push
              found: snapshotProp
              expected: expectationProp
        diffs

      # Compares a snapshot with what is currently expected.
      compare = (snapshot, expectation) =>
        # Logs an error if the snapshot isn't what we expected.
        log differences(snapshot, expectation)

        # log snapshot, expectation  unless 
        
        # After running the comparison, we should stop waiting and run the next step.
        @_actionQueue.complete()

      gathererContext = {}
      next = (snapshot) =>
        
        # When the gatherer provides a snapshot, run a comparison.
        unless _.isEmpty(settings.expect)
          compare snapshot, settings.expect
        else
          # Stop waiting and run the next step.
          @_actionQueue.complete()

      
      # Gather our state.
      settings.gather.call gathererContext, next

    @_mutatorContext = {}
      

  snap: =>
    @name = ""
    mutator = (go) =>
      go()

    if _.isFunction(arguments[0])
      mutator = arguments[0]
    else if _.isString(arguments[0]) and _.isFunction(arguments[1])
      @name = arguments[0]
      mutator = arguments[1]
    
    # Adds the link's action to the queue.
    @_actionQueue.addAction =>
      
      # Every step waits.
      @_actionQueue.wait =>
        
        # After waiting, run the next step.
        @_actionQueue.runNextStep()

      
      # Increment the link count and call the mutator.
      @_index++
      mutator.call @_mutatorContext, @_go, @_index, @name

    
    # After we load the first action into the queue, run it.
    @_actionQueue.endStep()
    @_actionQueue.runNextStep()
    
    # Snap is chainable.
    @

module.exports = SnapChain

