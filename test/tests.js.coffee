assert = require 'assert'
sinon = require 'sinon'
SnapChain = require '../index'

describe "Snap chain", ->
  describe "Action queue", ->
    it "should call a transformation when it's snapped into the chain", ->
      chain = new SnapChain "Test chain"

      t1 = sinon.spy((go) ->
        go()
      )

      t2 = sinon.spy((go) ->
        go()
      )

      t3 = sinon.spy((go) ->
        go()
      )

      chain.snap "1st chain transformation", t1

      assert(t1.called, "t1 wasn't called, but should've been")
      assert(!t2.called, "t2 was called, but shouldn't have been")
      assert(!t3.called, "t3 was called, but shouldn't have been")

      chain.snap "2nd chain transformation", t2

      assert(t1.called, "t1 wasn't called, but should've been")
      assert(t2.called, "t2 wasn't called, but should've been")
      assert(!t3.called, "t3 was called, but shouldn't have been")

      chain.snap "3rd chain transformation", t3

      assert(t1.called, "t1 wasn't called, but should've been")
      assert(t2.called, "t2 wasn't called, but should've been")
      assert(t3.called, "t3 wasn't called, but should've been")

    it "should halt the execution of a chain when a transformation fails to call `go()`", ->
      chain = new SnapChain "Test chain"

      t1 = sinon.spy((go) ->
        go()
      )

      t2 = sinon.spy((go) ->)

      t3 = sinon.spy((go) ->
        go()
      )

      chain.snap "1st chain transformation", t1
      chain.snap "2nd chain transformation", t2
      chain.snap "3rd chain transformation", t3

      assert(t1.called, "t1 wasn't called, but should've been")
      assert(t2.called, "t2 wasn't called, but should've been")
      assert(!t3.called, "t3 was called, but shouldn't have been")

    it "should unpause chain when a transformation's `go()` is called", ->
      chain = new SnapChain "Test chain"

      t1 = sinon.spy (go) ->
        go()

      delayedEffect = null

      t2 = sinon.spy (go) ->
        delayedEffect = ->
          go()

      t3 = sinon.spy (go) ->
        go()

      chain.snap "1st chain transformation", t1
      chain.snap "2nd chain transformation", t2
      chain.snap "3rd chain transformation", t3

      assert(t1.called, "t1 wasn't called, but should've been")
      assert(t2.called, "t2 wasn't called, but should've been")
      assert(!t3.called, "t3 was called, but shouldn't have been")

      delayedEffect()

      assert(t1.called, "t1 wasn't called, but should've been")
      assert(t2.called, "t2 wasn't called, but should've been")
      assert(t3.called, "t3 wasn't called, but should've been")

    it "should give each chain transformation access to a common context", ->
      chain = new SnapChain "Test chain"

      chain.snap "1st chain transformation", (go, i, name) ->
        assert(i == 0, "arg index should be 0")
        assert(name == "1st chain transformation", "arg name is not what we set it to")
        go()
      assert.deepEqual(chain._mutatorContext, {})
      assert(chain._index == 0, "index should be 0")
      assert(chain.name == "1st chain transformation", "name is not what we set it to")

      chain.snap "2nd chain transformation", (go, i, name) ->
        @foo = 'bar'
        assert(i == 1, "arg index should be 1")
        assert(name == "2nd chain transformation", "arg name is not what we set it to")
        go()
      assert.deepEqual(chain._mutatorContext, {foo:'bar'})
      assert(chain._index == 1, "index should be 1")
      assert(chain.name == "2nd chain transformation", "name is not what we set it to")

      chain.snap "3rd chain transformation", (go, i, name) ->
        @foo = 12
        @bar = 'baz'
        assert(i == 2, "arg index should be 2")
        assert(name == "3rd chain transformation", "arg name is not what we set it to")
        go()
      assert.deepEqual(chain._mutatorContext, {foo:12,bar:'baz'})
      assert(chain._index == 2, "index should be 2")
      assert(chain.name == "3rd chain transformation", "name is not what we set it to")

      chain.snap "4th chain transformation", (go, i, name) ->
        @bar = 3
        assert(i == 3, "arg index should be 3")
        assert(name == "4th chain transformation", "arg name is not what we set it to")
        go()
      assert.deepEqual(chain._mutatorContext, {foo:12,bar:3})
      assert(chain._index == 3, "index should be 3")
      assert(chain.name == "4th chain transformation", "name is not what we set it to")

  describe "Constraining tool", ->
    it "should repeatedly call the last gatherer that was set into the chain", ->
      stuff =
        foo: 'bar'
        baz: 12
      chain = new SnapChain "Test chain"

      chain.snap "1st chain transformation", (go) ->
        go()

      gatherer1 = sinon.spy (go) ->
        go(stuff)
      chain.snap "2nd chain transformation", (go) ->
        go(gather: gatherer1)
      assert(gatherer1.callCount == 1, "gatherer1 was called "+gatherer1.callCount+" times, but should've been called once")

      chain.snap "3rd chain transformation", (go) ->
        go()
      assert(gatherer1.callCount == 2, "gatherer1 was called "+gatherer1.callCount+" times, but should've been called twice")

      gatherer2 = sinon.spy (go) ->
        go(stuff.foo)
      chain.snap "4th chain transformation", (go) ->
        go(gather: gatherer2)
      assert(gatherer1.callCount == 2, "gatherer1 was called "+gatherer1.callCount+" times, but should've been called twice")
      assert(gatherer2.callCount == 1, "gatherer2 was called "+gatherer2.callCount+" times, but should've been called once")

      chain.snap "5th chain transformation", (go) ->
        go()
      assert(gatherer1.callCount == 2, "gatherer1 was called "+gatherer1.callCount+" times, but should've been called twice")
      assert(gatherer2.callCount == 2, "gatherer2 was called "+gatherer2.callCount+" times, but should've been called twice")


    it "should compare gathered state with expected state", ->
      stuff =
        foo: 'bar'
        baz: 12
      chain = new SnapChain "Test chain"

      chain.snap "1st chain transformation", (go) ->
        go()

      diffCount = 0
      gatherer1 = sinon.spy (go) ->
        diffCount = go(stuff)
      chain.snap "2nd chain transformation", (go) ->
        go(gather: gatherer1, expect:{foo: 'foo'})
      assert(gatherer1.callCount == 1, "gatherer1 was called "+gatherer1.callCount+" times, but should've been called once")
      assert(diffCount == 1, "diff count was "+diffCount+", but should've been 1")

      chain.snap "3rd chain transformation", (go) ->
        go(expect: {baz:12, foo:'baz', a:2})
      assert(gatherer1.callCount == 2, "gatherer1 was called "+gatherer1.callCount+" times, but should've been called twice")
      assert(diffCount == 2, "diff count was "+diffCount+", but should've been 2")

      gatherer2 = sinon.spy (go) ->
        diffCount = go({foo:stuff.foo})
      chain.snap "4th chain transformation", (go) ->
        go(gather: gatherer2, expect: {foo:'foo'})
      assert(gatherer1.callCount == 2, "gatherer1 was called "+gatherer1.callCount+" times, but should've been called twice")
      assert(gatherer2.callCount == 1, "gatherer2 was called "+gatherer2.callCount+" times, but should've been called onces")
      assert(diffCount == 1, "diff count was "+diffCount+", but should've been 1")

      chain.snap "5th chain transformation", (go) ->
        go()
      assert(gatherer1.callCount == 2, "gatherer1 was called "+gatherer1.callCount+" times, but should've been called twice")
      assert(gatherer2.callCount == 2, "gatherer2 was called "+gatherer2.callCount+" times, but should've been called twice")
      assert(diffCount == 0, "diff count was "+diffCount+", but should've been 0")

      chain.snap "6th chain transformation", (go) ->
        go({})
      assert(gatherer1.callCount == 2, "gatherer1 was called "+gatherer1.callCount+" times, but should've been called twice")
      assert(gatherer2.callCount == 3, "gatherer2 was called "+gatherer2.callCount+" times, but should've been called three times")
      assert(diffCount == 0, "diff count was "+diffCount+", but should've been 0")




