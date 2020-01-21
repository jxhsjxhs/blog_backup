---
title: kube-dns与CoreDNS有何差异？
date: 2020-01-20 16:17:57
tags:
---

使用kube-dns集群插件，基于DNS的服务发现已成为Kubernetes的一部分。这通常很有效，但是对于实施的可靠性、灵活性和安全性存在一些担忧。

CoreDNS是一个通用的、权威的DNS服务器，提供与Kubernetes后向兼容但可扩展的集成。它解决了kube-dns所遇到的问题，并提供了许多独特的功能，可以解决各种各样的用例。

在本文中，你将了解kube-dns和CoreDNS的实施差异，以及CoreDNS提供的一些有用的扩展。

### 实施差异
在kube-dns中，一个pod内使用了数个容器：kubedns、dnsmasq和sidecar。 kubedns容器监视Kubernetes API并基于Kubernetes DNS规范提供DNS记录，dnsmasq提供缓存和存根域支持，sidecar提供指标和健康检查。

此设置会导致一些问题随着时间的推移而出现。首先，dnsmasq中的安全漏洞导致过去需要发布Kubernetes安全补丁。此外，由于dnsmasq处理存根域，但kubedns处理External Services，因此你无法在外部服务中使用存根域，这非常限制该功能（参阅dns＃131）。

在CoreDNS中，所有这些功能都在一个容器中完成——该容器运行用Go编写的进程。启用的不同插件来复制（并增强）kube-dns中的功能。


### 配置CoreDNS


在kube-dns中，你可以修改ConfigMap以改变服务发现的行为。这允许添加诸如提供服务存根域、修改上游名称服务器以及启用联合之类的功能。

在CoreDNS中，你同样可以修改CoreDNS Corefile的ConfigMap以更改服务发现的工作方式。Corefile配置提供了比kube-dns更多的选项，因为它是CoreDNS用于配置其所有功能（甚至是那些与Kubernetes无关的功能）的主要配置文件。

使用kubeadm从kube-dns升级到CoreDNS时，现有的ConfigMap将用于为你生成自定义Corefile，包括存根域、联合和上游名称服务器的所有配置。有关更多详细信息，请参阅《使用CoreDNS进行服务发现》。

### bug修复和增强功能

kube-dns有几个还没解决的问题，而这些问题在CoreDNS中得到解决，无论是默认配置还是某些自定义配置。

——dns＃55：kube-dns的自定义DNS条目可以通过使用kubernetes插件中的“fallthrough”机制、使用重写插件或者仅使用不同的插件（如文件插件）提供子区域来处理。

——dns＃116：只有一个A记录集用于具有单个主机名的pod无头服务。此问题已修复，无需任何其他配置。

——dns＃131： externalName不使用stubDomains设置。此问题已修复，无需任何其他配置。

——dns＃167：启用skyDNS循环A / AAAA记录。可以使用负载均衡插件配置等效功能。

——dns＃190：kube-dns无法以非root用户身份运行。现在通过使用非默认镜像解决了此问题，但在将来的版本中它将成为默认的CoreDNS行为。

——dns＃232：将pod hostname修复为dns srv记录的podname，这是通过下面描述的“endpoint_pod_names”功能支持的增强功能。

### 指标

默认CoreDNS配置的功能行为与kube-dns相同。但是，你需要知道的一个区别是发布的指标不同。在kube-dns中，你可以获得单独的dnsmasq和kubedns（skydns）指标。在CoreDNS中，有一组完全不同的指标，因为它只是一个单一的进程。你可以在CoreDNS Prometheus插件页面上找到有关这些指标的更多详细信息。

### 一些特殊功能

标准CoreDNS Kubernetes配置旨在向后兼容之前的kube-dns行为。但是，通过一些配置更改，CoreDNS可以允许你修改DNS服务发现在集群中的工作方式。许多这样的功能旨在仍然符合Kubernetes DNS规范：它们增强了功能，但保持向后兼容。由于CoreDNS不仅仅是为Kubernetes而设计的，而是一个通用的DNS服务器，因此除了该规范之外，你还可以做很多事情。

### pod verified模式

在kube-dns中，pod名称记录是“假的”。也就是说，任何“a-b-c-d.namespace.pod.cluster.local”查询都将返回IP地址“a.b.c.d”。在某些情况下，这会削弱TLS提供的身份保证。因此，CoreDNS提供“pods verified”模式，如果指定的命名空间中有一个具有该IP地址的pod，它将仅返回IP地址。

### 端点名称基于pod名称

在kube-dns中，当使用无头服务时，你可以使用SRV请求来获取服务的所有端点的列表：

dnstools# host -t srv headless

headless.default.svc.cluster.local has SRV record 10 33 0 6234396237313665.headless.default.svc.cluster.local.

headless.default.svc.cluster.local has SRV record 10 33 0 6662363165353239.headless.default.svc.cluster.local.

headless.default.svc.cluster.local has SRV record 10 33 0 6338633437303230.headless.default.svc.cluster.local.

dnstools#

但是，端点DNS名称（出于实用目的）是随机的。在CoreDNS中，默认情况下，你将根据端点的IP地址获取端点DNS名称：

dnstools# host -t srv headless

headless.default.svc.cluster.local has SRV record 0 25 443 172-17-0-14.headless.default.svc.cluster.local.

headless.default.svc.cluster.local has SRV record 0 25 443 172-17-0-18.headless.default.svc.cluster.local.

headless.default.svc.cluster.local has SRV record 0 25 443 172-17-0-4.headless.default.svc.cluster.local.

headless.default.svc.cluster.local has SRV record 0 25 443 172-17-0-9.headless.default.svc.cluster.local.

对于某些应用程序，需要为此设置pod名称，而不是pod IP地址（例如，请参阅kubernetes＃47992和coredns＃1190）。要在CoreDNS中启用此功能，请在Corefile中指定“endpoint_pod_names”选项，结果如下：

dnstools# host -t srv headless

headless.default.svc.cluster.local has SRV record 0 25 443 headless-65bb4c479f-qv84p.headless.default.svc.cluster.local.

headless.default.svc.cluster.local has SRV record 0 25 443 headless-65bb4c479f-zc8lx.headless.default.svc.cluster.local.

headless.default.svc.cluster.local has SRV record 0 25 443 headless-65bb4c479f-q7lf2.headless.default.svc.cluster.local.

headless.default.svc.cluster.local has SRV record 0 25 443 headless-65bb4c479f-566rt.headless.default.svc.cluster.local.

### Autopath

CoreDNS还具有一项特殊功能，可以改善外部名称DNS请求的延迟。 在Kubernetes中，pod的DNS搜索路径指定了一长串后缀。这样可以在请求集群中的服务时使用短名称，例如上面的“headless”，而不是“headless.default.svc.cluster.local”。 但是，当请求外部名称（例如“infoblox.com”时 ），客户端进行了好几次无效的DNS查询，每次都需要从客户端到kube-dns的往返：

infoblox.com.default.svc.cluster.local -> NXDOMAIN
infoblox.com.svc.cluster.local -> NXDOMAIN
infoblox.com.cluster.local -> NXDOMAIN
infoblox.com.your-internal-domain.com -> NXDOMAIN
infoblox.com -> returns a valid record
在CoreDNS中，可以启用一个名为autopath的可选功能。该功能将导致在服务器中跟踪此搜索路径。也就是说，CoreDNS将从源IP地址中找出客户端pod所在的命名空间，并遍历此搜索列表，直到获得有效答案。由于前三个在CoreDNS内部解析，因此它会切断客户端和服务器之间的所有来回，从而减少延迟。

### 其他Kubernetes特定功能

在CoreDNS中，你可以使用标准DNS区域传输来导出整个DNS记录集。这对于调试服务以及将集群区域导入其他DNS服务器非常有用。

你还可以按命名空间或标签选择器进行过滤。这可以允许你运行特定的CoreDNS实例——这些实例仅服务于与过滤器匹配的记录，通过DNS公开一组有限的服务。

### 可扩展性

除了上述功能外，CoreDNS还可以轻松扩展。可以构建CoreDNS的自定义版本。例如，此功能已用于扩展CoreDNS以使用未绑定插件进行递归解析，使用pdsql插件直接从数据库服务记录，并允许多个CoreDNS实例与redisc插件共享公共2级缓存。

还添加了许多其他有趣的扩展——你可以在CoreDNS站点的External Plugins页面上找到它们。Kubernetes和Istio用户真正感兴趣的是kubernetai插件，它允许单个CoreDNS实例连接到多个Kubernetes集群并提供跨所有这些集群的服务发现。
