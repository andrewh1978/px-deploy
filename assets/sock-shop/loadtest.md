
<h2>Load test / Dummy content</h2>
<p>This is a useful tool for demonstrating what happens whilst under load during a failover event.</p>
<p>
The load test packages a test script in a container for <a href="http://locust.io/">Locust</a> that simulates user traffic to Sock Shop, please run it against the front-end service.
The address and port of the frontend will be different and depend on which platform you've deployed to.
See the notes for each deployment.
</p>
<p>
For example, on the <a href="/docs/docker-single-weave.html">Docker (single-host with Weave)</a> deployment, on Docker for Mac:
<pre><code>docker run --net=host weaveworksdemos/load-test -h localhost -r 100 -c 2</code></pre>
</p>
<p>
The syntax for running the load test container is:
<pre><code>docker run --net=host weaveworksdemos/load-test -h $frontend-ip[:$port] -r 100 -c 2</code></pre>
</p>
<p>
The help command provides more details about the parameters:
<pre><code>$ docker run weaveworksdemos/load-test --help
Usage:
  docker run weaveworksdemos/load-test [ hostname ] OPTIONS

Options:
  -d  Delay before starting
  -h  Target host url, e.g. localhost:80
  -c  Number of clients (default 2)
  -r  Number of requests (default 10)

Description:
  Runs a Locust load simulation against specified host.</code></pre>
</p>
