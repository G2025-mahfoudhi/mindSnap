2026-06-04T09:33:09.318772+00:00 app[web.1]: [c3fbf745-d685-e7c6-2a58-e7ddc35bdb28]   Rendered layout layouts/application.html.erb (Duration: 6.1ms | GC: 0.3ms)
2026-06-04T09:33:09.318969+00:00 app[web.1]: [c3fbf745-d685-e7c6-2a58-e7ddc35bdb28] Completed 200 OK in 7ms (Views: 6.0ms | ActiveRecord: 0.6ms (1 query, 0 cached) | GC: 0.3ms)
2026-06-04T09:33:09.320600+00:00 heroku[router]: at=info method=GET path="/" host=mindsnap-3fe93d03cb75.herokuapp.com request_id=c3fbf745-d685-e7c6-2a58-e7ddc35bdb28 fwd="86.217.43.144" dyno=web.1 connect=0ms service=12ms status=200 bytes=16268 protocol=http1.1 tls=false
2026-06-04T09:33:10.698401+00:00 app[web.1]: [2fc5a95f-fcf3-3f31-243e-71cec6aa78ca] Started GET "/espaces" for 86.217.43.144 at 2026-06-04 09:33:10 +0000
2026-06-04T09:33:10.698987+00:00 app[web.1]: [2fc5a95f-fcf3-3f31-243e-71cec6aa78ca] Processing by EspacesController#index as HTML
2026-06-04T09:33:10.763041+00:00 app[web.1]: [2fc5a95f-fcf3-3f31-243e-71cec6aa78ca]   Rendered layout layouts/application.html.erb (Duration: 54.0ms | GC: 0.3ms)
2026-06-04T09:33:10.764388+00:00 app[web.1]: [2fc5a95f-fcf3-3f31-243e-71cec6aa78ca] Completed 200 OK in 65ms (Views: 48.9ms | ActiveRecord: 8.3ms (10 queries, 1 cached) | GC: 0.9ms)
2026-06-04T09:33:10.766320+00:00 heroku[router]: at=info method=GET path="/espaces" host=mindsnap-3fe93d03cb75.herokuapp.com request_id=2fc5a95f-fcf3-3f31-243e-71cec6aa78ca fwd="86.217.43.144" dyno=web.1 connect=0ms service=70ms status=200 bytes=20211 protocol=http1.1 tls=false
2026-06-04T09:33:12.419631+00:00 app[web.1]: [3fb48797-70fe-f9dd-90c6-7cb64d5cf6eb] Started GET "/documents/13" for 86.217.43.144 at 2026-06-04 09:33:12 +0000
2026-06-04T09:33:12.421313+00:00 app[web.1]: [3fb48797-70fe-f9dd-90c6-7cb64d5cf6eb] Processing by DocumentsController#show as HTML
2026-06-04T09:33:12.421326+00:00 app[web.1]: [3fb48797-70fe-f9dd-90c6-7cb64d5cf6eb]   Parameters: {"id"=>"13"}
2026-06-04T09:33:12.451725+00:00 app[web.1]: [3fb48797-70fe-f9dd-90c6-7cb64d5cf6eb]   Rendered layout layouts/application.html.erb (Duration: 22.4ms | GC: 1.7ms)
2026-06-04T09:33:12.451940+00:00 app[web.1]: [3fb48797-70fe-f9dd-90c6-7cb64d5cf6eb] Completed 200 OK in 30ms (Views: 19.4ms | ActiveRecord: 5.9ms (10 queries, 0 cached) | GC: 1.7ms)
2026-06-04T09:33:12.453678+00:00 heroku[router]: at=info method=GET path="/documents/13" host=mindsnap-3fe93d03cb75.herokuapp.com request_id=3fb48797-70fe-f9dd-90c6-7cb64d5cf6eb fwd="86.217.43.144" dyno=web.1 connect=0ms service=35ms status=200 bytes=18283 protocol=http1.1 tls=false
2026-06-04T09:33:13.989866+00:00 app[web.1]: [aa320e39-1e58-0d53-f88c-17cbfc1f6734] Started GET "/documents/13/download?blob_signed_id=eyJfcmFpbHMiOnsiZGF0YSI6MTAsInB1ciI6ImJsb2JfaWQifX0%3D--0ce477534c36f65a45501a9e380a003d557a7ab1" for 86.217.43.144 at 2026-06-04 09:33:13 +0000
2026-06-04T09:33:13.990443+00:00 app[web.1]: [aa320e39-1e58-0d53-f88c-17cbfc1f6734] Processing by DocumentsController#download as HTML
2026-06-04T09:33:13.990459+00:00 app[web.1]: [aa320e39-1e58-0d53-f88c-17cbfc1f6734]   Parameters: {"blob_signed_id"=>"eyJfcmFpbHMiOnsiZGF0YSI6MTAsInB1ciI6ImJsb2JfaWQifX0=--0ce477534c36f65a45501a9e380a003d557a7ab1", "id"=>"13"}
2026-06-04T09:33:14.023275+00:00 app[web.1]: [aa320e39-1e58-0d53-f88c-17cbfc1f6734] Redirected to https://res.cloudinary.com/mindsnap/image/upload/fl_attachment:Heroku_(1)/v1/production/x7riyb0t3w19nw23h7jadvpmheh2?_a=BACMTiEv
2026-06-04T09:33:14.023386+00:00 app[web.1]: [aa320e39-1e58-0d53-f88c-17cbfc1f6734] Completed 302 Found in 33ms (ActiveRecord: 2.0ms (5 queries, 1 cached) | GC: 0.3ms)
2026-06-04T09:33:14.024454+00:00 heroku[router]: at=info method=GET path="/documents/13/download?blob_signed_id=eyJfcmFpbHMiOnsiZGF0YSI6MTAsInB1ciI6ImJsb2JfaWQifX0%3D--0ce477534c36f65a45501a9e380a003d557a7ab1" host=mindsnap-3fe93d03cb75.herokuapp.com request_id=aa320e39-1e58-0d53-f88c-17cbfc1f6734 fwd="86.217.43.144" dyno=web.1 connect=0ms service=37ms status=302 bytes=0 protocol=http1.1 tls=false
2026-06-04T09:33:15.832064+00:00 app[web.1]: [72e9f3e9-3645-efbb-6514-1a27b6e72097] Started GET "/documents/13/download?blob_signed_id=eyJfcmFpbHMiOnsiZGF0YSI6MTAsInB1ciI6ImJsb2JfaWQifX0%3D--0ce477534c36f65a45501a9e380a003d557a7ab1" for 86.217.43.144 at 2026-06-04 09:33:15 +0000
2026-06-04T09:33:15.832649+00:00 app[web.1]: [72e9f3e9-3645-efbb-6514-1a27b6e72097] Processing by DocumentsController#download as HTML
2026-06-04T09:33:15.832667+00:00 app[web.1]: [72e9f3e9-3645-efbb-6514-1a27b6e72097]   Parameters: {"blob_signed_id"=>"eyJfcmFpbHMiOnsiZGF0YSI6MTAsInB1ciI6ImJsb2JfaWQifX0=--0ce477534c36f65a45501a9e380a003d557a7ab1", "id"=>"13"}
2026-06-04T09:33:15.845897+00:00 app[web.1]: [72e9f3e9-3645-efbb-6514-1a27b6e72097] Redirected to https://res.cloudinary.com/mindsnap/image/upload/fl_attachment:Heroku_(1)/v1/production/x7riyb0t3w19nw23h7jadvpmheh2?_a=BACMTiEv
2026-06-04T09:33:15.845996+00:00 app[web.1]: [72e9f3e9-3645-efbb-6514-1a27b6e72097] Completed 302 Found in 13ms (ActiveRecord: 2.1ms (5 queries, 1 cached) | GC: 0.0ms)
2026-06-04T09:33:15.846752+00:00 heroku[router]: at=info method=GET path="/documents/13/download?blob_signed_id=eyJfcmFpbHMiOnsiZGF0YSI6MTAsInB1ciI6ImJsb2JfaWQifX0%3D--0ce477534c36f65a45501a9e380a003d557a7ab1" host=mindsnap-3fe93d03cb75.herokuapp.com request_id=72e9f3e9-3645-efbb-6514-1a27b6e72097 fwd="86.217.43.144" dyno=web.1 connect=0ms service=16ms status=302 bytes=0 protocol=http1.1 tls=false
2026-06-04T09:34:00.777606+00:00 app[web.1]: [949b9b97-dabb-1826-97bb-b1e6b64b57b1] Started GET "/" for 86.217.43.144 at 2026-06-04 09:34:00 +0000
2026-06-04T09:34:00.778846+00:00 app[web.1]: [949b9b97-dabb-1826-97bb-b1e6b64b57b1] Processing by PagesController#home as HTML
2026-06-04T09:34:00.787319+00:00 app[web.1]: [949b9b97-dabb-1826-97bb-b1e6b64b57b1]   Rendered layout layouts/application.html.erb (Duration: 7.5ms | GC: 0.2ms)
2026-06-04T09:34:00.787466+00:00 app[web.1]: [949b9b97-dabb-1826-97bb-b1e6b64b57b1] Completed 200 OK in 9ms (Views: 7.6ms | ActiveRecord: 0.6ms (1 query, 0 cached) | GC: 0.2ms)
2026-06-04T09:34:00.788859+00:00 heroku[router]: at=info method=GET path="/" host=mindsnap-3fe93d03cb75.herokuapp.com request_id=949b9b97-dabb-1826-97bb-b1e6b64b57b1 fwd="86.217.43.144" dyno=web.1 connect=0ms service=13ms status=200 bytes=16051 protocol=http1.1 tls=false
2026-06-04T09:34:04.426095+00:00 app[web.1]: [1dbcf045-59e0-4230-f7b7-9db663b70e2d] Started GET "/espaces" for 86.217.43.144 at 2026-06-04 09:34:04 +0000
2026-06-04T09:34:04.426616+00:00 app[web.1]: [1dbcf045-59e0-4230-f7b7-9db663b70e2d] Processing by EspacesController#index as HTML
2026-06-04T09:34:04.452575+00:00 app[web.1]: [1dbcf045-59e0-4230-f7b7-9db663b70e2d]   Rendered layout layouts/application.html.erb (Duration: 15.6ms | GC: 0.0ms)
2026-06-04T09:34:04.452734+00:00 app[web.1]: [1dbcf045-59e0-4230-f7b7-9db663b70e2d] Completed 200 OK in 26ms (Views: 13.0ms | ActiveRecord: 4.5ms (10 queries, 1 cached) | GC: 0.0ms)
2026-06-04T09:34:04.454231+00:00 heroku[router]: at=info method=GET path="/espaces" host=mindsnap-3fe93d03cb75.herokuapp.com request_id=1dbcf045-59e0-4230-f7b7-9db663b70e2d fwd="86.217.43.144" dyno=web.1 connect=0ms service=29ms status=200 bytes=20211 protocol=http1.1 tls=false
2026-06-04T09:34:04.912446+00:00 app[web.1]: [c1b75a6d-63b5-ad84-a340-2b7c9b53ecdf] Started GET "/espaces" for 86.217.43.144 at 2026-06-04 09:34:04 +0000
2026-06-04T09:34:04.913413+00:00 app[web.1]: [c1b75a6d-63b5-ad84-a340-2b7c9b53ecdf] Processing by EspacesController#index as HTML
2026-06-04T09:34:04.937168+00:00 app[web.1]: [c1b75a6d-63b5-ad84-a340-2b7c9b53ecdf]   Rendered layout layouts/application.html.erb (Duration: 13.2ms | GC: 0.0ms)
2026-06-04T09:34:04.937347+00:00 app[web.1]: [c1b75a6d-63b5-ad84-a340-2b7c9b53ecdf] Completed 200 OK in 24ms (Views: 10.7ms | ActiveRecord: 5.0ms (10 queries, 1 cached) | GC: 0.0ms)
2026-06-04T09:34:04.938880+00:00 heroku[router]: at=info method=GET path="/espaces" host=mindsnap-3fe93d03cb75.herokuapp.com request_id=c1b75a6d-63b5-ad84-a340-2b7c9b53ecdf fwd="86.217.43.144" dyno=web.1 connect=0ms service=27ms status=200 bytes=20211 protocol=http1.1 tls=false
2026-06-04T09:34:07.366859+00:00 app[web.1]: [1bce2c62-f68d-0a0e-c74f-fca79562485b] Started DELETE "/users/sign_out?_method=delete" for 86.217.43.144 at 2026-06-04 09:34:07 +0000
2026-06-04T09:34:07.367583+00:00 app[web.1]: [1bce2c62-f68d-0a0e-c74f-fca79562485b] Processing by Devise::SessionsController#destroy as TURBO_STREAM
2026-06-04T09:34:07.374324+00:00 app[web.1]: [1bce2c62-f68d-0a0e-c74f-fca79562485b] Redirected to https://mindsnap-3fe93d03cb75.herokuapp.com/
2026-06-04T09:34:07.374389+00:00 app[web.1]: [1bce2c62-f68d-0a0e-c74f-fca79562485b] Completed 303 See Other in 7ms (ActiveRecord: 0.6ms (1 query, 0 cached) | GC: 0.0ms)
2026-06-04T09:34:07.375856+00:00 heroku[router]: at=info method=POST path="/users/sign_out?_method=delete" host=mindsnap-3fe93d03cb75.herokuapp.com request_id=1bce2c62-f68d-0a0e-c74f-fca79562485b fwd="86.217.43.144" dyno=web.1 connect=0ms service=10ms status=303 bytes=0 protocol=http1.1 tls=false
2026-06-04T09:34:07.507191+00:00 app[web.1]: [4fb58217-ebd2-6257-4c83-96496f58964b] Started GET "/" for 86.217.43.144 at 2026-06-04 09:34:07 +0000
2026-06-04T09:34:07.507814+00:00 app[web.1]: [4fb58217-ebd2-6257-4c83-96496f58964b] Processing by PagesController#home as TURBO_STREAM
2026-06-04T09:34:07.510610+00:00 app[web.1]: [4fb58217-ebd2-6257-4c83-96496f58964b]   Rendered layout layouts/application.html.erb (Duration: 1.7ms | GC: 0.0ms)
2026-06-04T09:34:07.510759+00:00 app[web.1]: [4fb58217-ebd2-6257-4c83-96496f58964b] Completed 200 OK in 3ms (Views: 2.1ms | ActiveRecord: 0.0ms (0 queries, 0 cached) | GC: 0.0ms)
2026-06-04T09:34:07.512338+00:00 heroku[router]: at=info method=GET path="/" host=mindsnap-3fe93d03cb75.herokuapp.com request_id=4fb58217-ebd2-6257-4c83-96496f58964b fwd="86.217.43.144" dyno=web.1 connect=0ms service=8ms status=200 bytes=14951 protocol=http1.1 tls=false
2026-06-04T09:34:09.859128+00:00 app[web.1]: [b364a511-64b6-75f2-29cc-f7646fda7103] Started GET "/users/sign_in" for 86.217.43.144 at 2026-06-04 09:34:09 +0000
2026-06-04T09:34:09.859879+00:00 app[web.1]: [b364a511-64b6-75f2-29cc-f7646fda7103] Processing by Devise::SessionsController#new as HTML
2026-06-04T09:34:09.868205+00:00 app[web.1]: [b364a511-64b6-75f2-29cc-f7646fda7103]   Rendered layout layouts/devise.html.erb (Duration: 6.2ms | GC: 0.0ms)
2026-06-04T09:34:09.868372+00:00 app[web.1]: [b364a511-64b6-75f2-29cc-f7646fda7103] Completed 200 OK in 8ms (Views: 6.5ms | ActiveRecord: 0.0ms (0 queries, 0 cached) | GC: 0.0ms)
2026-06-04T09:34:09.869420+00:00 heroku[router]: at=info method=GET path="/users/sign_in" host=mindsnap-3fe93d03cb75.herokuapp.com request_id=b364a511-64b6-75f2-29cc-f7646fda7103 fwd="86.217.43.144" dyno=web.1 connect=0ms service=11ms status=200 bytes=8349 protocol=http1.1 tls=false
2026-06-04T09:34:12.114753+00:00 app[web.1]: [5679cb3e-832b-0940-de19-feb4cf901eb3] Started POST "/users/sign_in" for 86.217.43.144 at 2026-06-04 09:34:12 +0000
2026-06-04T09:34:12.115716+00:00 app[web.1]: [5679cb3e-832b-0940-de19-feb4cf901eb3] Processing by Devise::SessionsController#create as TURBO_STREAM
2026-06-04T09:34:12.115735+00:00 app[web.1]: [5679cb3e-832b-0940-de19-feb4cf901eb3]   Parameters: {"authenticity_token"=>"[FILTERED]", "user"=>{"email"=>"[FILTERED]", "password"=>"[FILTERED]", "remember_me"=>"0"}, "commit"=>"Se connecter"}
2026-06-04T09:34:12.347513+00:00 app[web.1]: [5679cb3e-832b-0940-de19-feb4cf901eb3] Redirected to https://mindsnap-3fe93d03cb75.herokuapp.com/
2026-06-04T09:34:12.347572+00:00 app[web.1]: [5679cb3e-832b-0940-de19-feb4cf901eb3] Completed 303 See Other in 232ms (ActiveRecord: 0.6ms (1 query, 0 cached) | GC: 0.0ms)
2026-06-04T09:34:12.348451+00:00 heroku[router]: at=info method=POST path="/users/sign_in" host=mindsnap-3fe93d03cb75.herokuapp.com request_id=5679cb3e-832b-0940-de19-feb4cf901eb3 fwd="86.217.43.144" dyno=web.1 connect=0ms service=234ms status=303 bytes=0 protocol=http1.1 tls=false
2026-06-04T09:34:12.426651+00:00 app[web.1]: [14c51b18-88ca-8e0b-1ce4-622c0a85c5f4] Started GET "/" for 86.217.43.144 at 2026-06-04 09:34:12 +0000
2026-06-04T09:34:12.427176+00:00 app[web.1]: [14c51b18-88ca-8e0b-1ce4-622c0a85c5f4] Processing by PagesController#home as TURBO_STREAM
2026-06-04T09:34:12.433714+00:00 app[web.1]: [14c51b18-88ca-8e0b-1ce4-622c0a85c5f4]   Rendered layout layouts/application.html.erb (Duration: 4.5ms | GC: 0.0ms)
2026-06-04T09:34:12.433842+00:00 app[web.1]: [14c51b18-88ca-8e0b-1ce4-622c0a85c5f4] Completed 200 OK in 7ms (Views: 5.6ms | ActiveRecord: 0.6ms (1 query, 0 cached) | GC: 0.0ms)
2026-06-04T09:34:12.435398+00:00 heroku[router]: at=info method=GET path="/" host=mindsnap-3fe93d03cb75.herokuapp.com request_id=14c51b18-88ca-8e0b-1ce4-622c0a85c5f4 fwd="86.217.43.144" dyno=web.1 connect=0ms service=9ms status=200 bytes=16268 protocol=http1.1 tls=false
2026-06-04T09:34:13.325787+00:00 app[web.1]: [c84cbc38-a150-4331-e0c5-54d02255a75a] Started GET "/espaces" for 86.217.43.144 at 2026-06-04 09:34:13 +0000
2026-06-04T09:34:13.326710+00:00 app[web.1]: [c84cbc38-a150-4331-e0c5-54d02255a75a] Processing by EspacesController#index as HTML
2026-06-04T09:34:13.350906+00:00 app[web.1]: [c84cbc38-a150-4331-e0c5-54d02255a75a]   Rendered layout layouts/application.html.erb (Duration: 14.1ms | GC: 0.0ms)
2026-06-04T09:34:13.351064+00:00 app[web.1]: [c84cbc38-a150-4331-e0c5-54d02255a75a] Completed 200 OK in 24ms (Views: 11.7ms | ActiveRecord: 4.4ms (10 queries, 1 cached) | GC: 0.0ms)
2026-06-04T09:34:13.352899+00:00 heroku[router]: at=info method=GET path="/espaces" host=mindsnap-3fe93d03cb75.herokuapp.com request_id=c84cbc38-a150-4331-e0c5-54d02255a75a fwd="86.217.43.144" dyno=web.1 connect=0ms service=28ms status=200 bytes=20211 protocol=http1.1 tls=false
2026-06-04T09:34:15.246333+00:00 app[web.1]: [a8186819-b08a-103f-2bca-ba8746596fef] Started GET "/documents/9" for 86.217.43.144 at 2026-06-04 09:34:15 +0000
2026-06-04T09:34:15.259416+00:00 app[web.1]: [a8186819-b08a-103f-2bca-ba8746596fef] Processing by DocumentsController#show as HTML
2026-06-04T09:34:15.259422+00:00 app[web.1]: [a8186819-b08a-103f-2bca-ba8746596fef]   Parameters: {"id"=>"9"}
2026-06-04T09:34:15.295135+00:00 app[web.1]: [a8186819-b08a-103f-2bca-ba8746596fef]   Rendered layout layouts/application.html.erb (Duration: 26.3ms | GC: 0.5ms)
2026-06-04T09:34:15.295313+00:00 app[web.1]: [a8186819-b08a-103f-2bca-ba8746596fef] Completed 200 OK in 36ms (Views: 23.9ms | ActiveRecord: 4.7ms (10 queries, 0 cached) | GC: 0.5ms)
2026-06-04T09:34:15.296691+00:00 heroku[router]: at=info method=GET path="/documents/9" host=mindsnap-3fe93d03cb75.herokuapp.com request_id=a8186819-b08a-103f-2bca-ba8746596fef fwd="86.217.43.144" dyno=web.1 connect=0ms service=51ms status=200 bytes=18246 protocol=http1.1 tls=false
2026-06-04T09:34:15.583702+00:00 app[web.1]: [44166393-dff3-fa42-ce52-db1e4349026d] Started GET "/documents/13" for 86.217.43.144 at 2026-06-04 09:34:15 +0000
2026-06-04T09:34:15.586533+00:00 app[web.1]: [44166393-dff3-fa42-ce52-db1e4349026d] Processing by DocumentsController#show as HTML
2026-06-04T09:34:15.586548+00:00 app[web.1]: [44166393-dff3-fa42-ce52-db1e4349026d]   Parameters: {"id"=>"13"}
2026-06-04T09:34:15.613300+00:00 app[web.1]: [44166393-dff3-fa42-ce52-db1e4349026d]   Rendered layout layouts/application.html.erb (Duration: 12.9ms | GC: 0.4ms)
2026-06-04T09:34:15.613510+00:00 app[web.1]: [44166393-dff3-fa42-ce52-db1e4349026d] Completed 200 OK in 27ms (Views: 10.5ms | ActiveRecord: 4.8ms (10 queries, 0 cached) | GC: 0.9ms)
2026-06-04T09:34:15.628535+00:00 heroku[router]: at=info method=GET path="/documents/13" host=mindsnap-3fe93d03cb75.herokuapp.com request_id=44166393-dff3-fa42-ce52-db1e4349026d fwd="86.217.43.144" dyno=web.1 connect=0ms service=55ms status=200 bytes=18283 protocol=http1.1 tls=false
2026-06-04T09:34:16.895647+00:00 app[web.1]: [a6950ae8-56a3-8c34-7aa1-d7a89f171def] Started GET "/documents/13/download?blob_signed_id=eyJfcmFpbHMiOnsiZGF0YSI6MTAsInB1ciI6ImJsb2JfaWQifX0%3D--0ce477534c36f65a45501a9e380a003d557a7ab1" for 86.217.43.144 at 2026-06-04 09:34:16 +0000
2026-06-04T09:34:16.896240+00:00 app[web.1]: [a6950ae8-56a3-8c34-7aa1-d7a89f171def] Processing by DocumentsController#download as HTML
2026-06-04T09:34:16.896258+00:00 app[web.1]: [a6950ae8-56a3-8c34-7aa1-d7a89f171def]   Parameters: {"blob_signed_id"=>"eyJfcmFpbHMiOnsiZGF0YSI6MTAsInB1ciI6ImJsb2JfaWQifX0=--0ce477534c36f65a45501a9e380a003d557a7ab1", "id"=>"13"}
2026-06-04T09:34:16.903442+00:00 app[web.1]: [a6950ae8-56a3-8c34-7aa1-d7a89f171def] Redirected to https://res.cloudinary.com/mindsnap/image/upload/fl_attachment:Heroku_(1)/v1/production/x7riyb0t3w19nw23h7jadvpmheh2?_a=BACMTiEv
2026-06-04T09:34:16.903560+00:00 app[web.1]: [a6950ae8-56a3-8c34-7aa1-d7a89f171def] Completed 302 Found in 7ms (ActiveRecord: 1.9ms (5 queries, 1 cached) | GC: 0.3ms)
2026-06-04T09:34:16.904914+00:00 heroku[router]: at=info method=GET path="/documents/13/download?blob_signed_id=eyJfcmFpbHMiOnsiZGF0YSI6MTAsInB1ciI6ImJsb2JfaWQifX0%3D--0ce477534c36f65a45501a9e380a003d557a7ab1" host=mindsnap-3fe93d03cb75.herokuapp.com request_id=a6950ae8-56a3-8c34-7aa1-d7a89f171def fwd="86.217.43.144" dyno=web.1 connect=0ms service=10ms status=302 bytes=0 protocol=http1.1 tls=false
2026-06-04T09:34:17.392347+00:00 app[web.1]: [ef666672-d2e0-bed4-3b04-dadae0eb903b] Started GET "/documents/13/download?blob_signed_id=eyJfcmFpbHMiOnsiZGF0YSI6MTAsInB1ciI6ImJsb2JfaWQifX0%3D--0ce477534c36f65a45501a9e380a003d557a7ab1" for 86.217.43.144 at 2026-06-04 09:34:17 +0000
2026-06-04T09:34:17.392990+00:00 app[web.1]: [ef666672-d2e0-bed4-3b04-dadae0eb903b] Processing by DocumentsController#download as HTML
2026-06-04T09:34:17.393012+00:00 app[web.1]: [ef666672-d2e0-bed4-3b04-dadae0eb903b]   Parameters: {"blob_signed_id"=>"eyJfcmFpbHMiOnsiZGF0YSI6MTAsInB1ciI6ImJsb2JfaWQifX0=--0ce477534c36f65a45501a9e380a003d557a7ab1", "id"=>"13"}
2026-06-04T09:34:17.399104+00:00 app[web.1]: [ef666672-d2e0-bed4-3b04-dadae0eb903b] Redirected to https://res.cloudinary.com/mindsnap/image/upload/fl_attachment:Heroku_(1)/v1/production/x7riyb0t3w19nw23h7jadvpmheh2?_a=BACMTiEv
2026-06-04T09:34:17.399209+00:00 app[web.1]: [ef666672-d2e0-bed4-3b04-dadae0eb903b] Completed 302 Found in 6ms (ActiveRecord: 1.8ms (5 queries, 1 cached) | GC: 0.3ms)
2026-06-04T09:34:17.400512+00:00 heroku[router]: at=info method=GET path="/documents/13/download?blob_signed_id=eyJfcmFpbHMiOnsiZGF0YSI6MTAsInB1ciI6ImJsb2JfaWQifX0%3D--0ce477534c36f65a45501a9e380a003d557a7ab1" host=mindsnap-3fe93d03cb75.herokuapp.com request_id=ef666672-d2e0-bed4-3b04-dadae0eb903b fwd="86.217.43.144" dyno=web.1 connect=0ms service=9ms status=302 bytes=0 protocol=http1.1 tls=false
2026-06-04T09:35:23.559250+00:00 app[api]: Log session created by user ghzelamahfoudhi@yahoo.fr
2026-06-04T09:35:39.877941+00:00 app[api]: Log session created by user ghzelamahfoudhi@yahoo.fr
2026-06-04T09:36:11.712595+00:00 app[api]: Log session created by user ghzelamahfoudhi@yahoo.fr
2026-06-04T09:37:39.641647+00:00 app[api]: Log session created by user ghzelamahfoudhi@yahoo.fr
