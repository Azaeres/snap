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

        diffs.length


      differences = (snapshot, expectation) =>
        # We'll clone the input here so that we see what they looked like
        # at the time they were logged to console, instead of being a live 
        # reference to the object.
        snapshot = _.clone(snapshot) || {}
        expectation = _.clone(expectation) || {}
        
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
        diffCount = log(differences(snapshot, expectation))

        # After running the comparison, we should stop waiting.
        # The onComplete callback then runs the next step.
        @_actionQueue.complete()
        diffCount

      gathererContext = {}
      next = (snapshot) =>
        diffCount = 0
        # When the gatherer provides a snapshot, run a comparison.
        unless _.isEmpty(settings.expect)
          diffCount = compare(snapshot, settings.expect)
        else
          # Stop waiting.
          # The onComplete callback then runs the next step.
          @_actionQueue.complete()
        diffCount
      
      # Gather our state.
      settings.gather.call gathererContext, next, @_index, @name, @

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
      
      # On complete, run the next step.
      @_actionQueue.onComplete =>
        @_actionQueue.runNextStep()

      # Every step waits.
      @_actionQueue.wait()

      
      # Increment the link count and call the mutator.
      @_index++
      mutator.call @_mutatorContext, @_go, @_index, @name, @

    
    # After we load the first action into the queue, run it.
    @_actionQueue.endStep()
    @_actionQueue.runNextStep()
    
    # Snap is chainable.
    @

module.exports = SnapChain

