1. Respond to a Ticket

Respond to this angry customer. You don't need to fix the problem, yet. Just let them know that you're sorry and working on it.

"HELP!
In fees, anywhere there should be a € symbol there is this code: `&#x20AC`;

This is embarassing. How could you ship something so broken?

-Ruben"

> I'm really sorry! I agree, this is embarrassing.
> 
> I'm looking into this now. You will be the first to know when this issue is resolved. If it is not fixed by 4:00 pm, I will update you.
> 
> Again, please accept my apology. I will take care of this.

2. Diagnose the Ticket

At a glance, what do you think is wrong in that ticket?

> There is a character encoding problem somewhere. It could be in the database, it could be in the html character set, it could be that the html entity is simply escaped, or maybe a gem is causing the problem.

3. Code Review

In less than a blog post, analyze the portal_controller.rb here:

https://gist.github.com/genericsteele/5ffef26c40d6a2927da8#file-portal_controller-rb

Try to answer these questions:

What does it do?
What do you like about it?
What don't you like about it?

> The PortalController controls client proposals. It includes some modules and helpers.
> 
> A couple of the expected methods are defined -- `index` and `show`. The `info` method redirects to `show` with an optional `preview` parameter. If that parameter is not set, the `ClientEmailer` sends an email to the user reporting that the proposal has been viewed.
> 
> `notify_honeybadger` (cute) handles errors, sending the exception.
> 
> `optional_fees` updates proposal fees associated with the proposal, updating the client_hide attribute depending on whether the client_hide attribute for the fee was submitted. 
> 
> `set_status` updates the proposal_status attribute. Accepted or declined proposals trigger an email to the user. I see some logging happening when status is changed. This might point to a need to move status to a model of its own to keep a history of changes. Or not -- sometimes I can be guilty of overkill. But digging through logs to find accidental changes can really be a pain. Approvals without electronic signatures are sent to the signature provide to be signed. I do see that status update times are recorded for the current_user's current visit.
> 
> I could go on to evaluate each method, but that would be one long snoozefest of a blog post. It is probably obvious that I understand what is going on.
> 
> This is probably a common observation: `notify_honeybadger` is a cute method name. It is always nice to find bits of code that make you smile. The filters are clear and the appropriate `skip_` prefix is used -- if you used `before_filter` with `:only` for `login_required` you would have a very long list of `:only`'s. Method names are clear and understandable.
> 
> The code formatting is a bit inconsistent. The perfectionist/seeker of symmetry in me would probably change some line breaks, but overall readablity is good. 
> 
> I would probably move note_failed_signin to the the sessions controller. This code is probably duplicated elsewhere. I also might look into adding a state machine to handle proposal status. The `set_status` and `accept` methods are quite long and could probably benefit from some refactoring.

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
