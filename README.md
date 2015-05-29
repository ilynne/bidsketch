1. Respond to a Ticket

Respond to this angry customer. You don't need to fix the problem, yet. Just let them know that you're sorry and working on it.

"HELP!
In fees, anywhere there should be a € symbol there is this code: &#x20AC;

This is embarassing. How could you ship something so broken?

-Ruben"

2. Diagnose the Ticket

At a glance, what do you think is wrong in that ticket?

3. Code Review

In less than a blog post, analyze the portal_controller.rb here:

https://gist.github.com/genericsteele/5ffef26c40d6a2927da8#file-portal_controller-rb

Try to answer these questions:

What does it do?
What do you like about it?
What don't you like about it?

4. Make Something

We use a service called Postmark to send emails. Sometimes these emails get bounced for any number of reasons and can't be sent. Postmark offers a bounce webhook that can notify us when one of our emails bounce. We need to build something that parses these notifications, and attempts to reactivate a bounce.

4.1 Plan it

Before you start building something, spend some time planning what this feature should or shouldn't do. Use the API docs as a guideline for what's possible. Keep security and the API limitations in mind. Use whatever other resources you can find to make your life easier. You should end up with a should/shouldn't list that looks something like this, but for a feature and not a cat:

It should catch mice
It should use a litter box
It should let me know when it's hungry
It should be fat, but not lazy
It should not try to send other cats to Abu Dabi

4.2 Build it

Give yourself an hour or two to build something that matches up with your requirements from 4.1.

4.3 Write about it

When you're done (doesn't have to be complete - don't go past two hours writing the code), bundle up the code and the requirements along with a short write-up of summarizing your work. I'm looking for introspection and honesty as much as code quality, so be sure to include things that got in your way and why.
