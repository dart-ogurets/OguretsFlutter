Feature: Test the sample flutter app

  Scenario: This tests the basic flutter app, not much can go wrong
    Given the counter is 0
    When I press the button 6 times
    Then the counter is 6