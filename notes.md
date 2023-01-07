# Kubernetes the hard way in Terraform
### 7 Jan 2023
A couple days ago, I read Learn Kubernetes the Hard Way, and generally read about the architecture of Kubernetes. I also brushed up on Terraform. Starting today, I want to solidify these two adventures by implementing Learn Kubernetes the Hard Way using Terraform, Ansible, Kustomize (or Helm) and otherwise making it more of a repeatable, idempotent process.

First, I will create a new project. I will not do this using Terraform, even though technically I could (within an organization). It's a fair bit of work, and it's a relatively rare thing to need to do.

First, I'm going to make a .env file so that I can store some frequently used terms and can load them later. For example, in that file I will put...

```
export project_name=learn-kube-hard-way-dmazin
```

That way I can `source .env` later to load my env vars.

Anyway, create the project. This step is not idempotent since project names must be globally unique.
    
```
gcloud projects create $project_name
```

And switch to the project.
```
gcloud config set project $project_name
```

Alrighty, now on to the TF config. First, we [configure some networking](https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/03-compute-resources.md#virtual-private-cloud-network).

I don't know yet how I will organize the TF directory – this is something I want to get better at. For now, I will stick networking-related stuff in a folder called networking.

Oh, one more thing. While I could define resources in Terraform directly, a nifty thing I saw a coworker do is extensivley use public modules vendored by Google. For example, [this module](https://registry.terraform.io/modules/terraform-google-modules/network/google/latest) lets you create networking stuff. (I might come to regret this... I'm not sure. I'm not terribly worried about losing out on learning, because I've created plenty of networking resources using TF. What I'm more worried about is that the modules will do far more than I need, and I'll struggle to fit them to my usecase. We'll see).

Oh, right. First, I need to create a service account + key and grant it `roles/editor`. You will find that in `bootstrap_service_account.sh`. Also, as I go along, I will need to enable various APIs via clickops.

OK, here we go. Let's define the VPC and subnet. You will find that under commit 6a7b4f64847bc97a8cdbb12c65362a0c1d161e3c.

(I tried to apply that, and at this point I needed to enable the compute API).

OK, network and subnet created (see commit 71e0629). One thing I learned: the docs for the Google modules are nearly useless; refer to the module file itself to learn how to use it.

Now, I will create the [firewall rules](https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/03-compute-resources.md#firewall-rules).

MAJOR VICTORY!!! When creating the firewall, I need to refer to the subnet CIDRs of the subnets I want to apply the firewall rule to. I found out how to do it dynamically!

The subnet module outputs the created subnets. I used `terraform console` to play around with the returned values, and then found that I can simply use a list comprehension to loop over the outputs: `[for s in module.subnets.subnets: s.ip_cidr_range]`.

Wee! I feel great. My firewall rules match the output in Learn Kubernetes the Hard Way. See commit 2bb2eaa. Wrapping up for the day.

### 7 Jan 2023
I'm so excited about this project that I woke up on a Saturday morning to continue working on it. :-) I think Eamon will sleep in for another 20 mins, at least.

The next step is to [allocate a public IP address](https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/03-compute-resources.md#kubernetes-public-ip-address). Done: see commit df108a4.

Next up: [creating the VMs](https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/03-compute-resources.md#compute-instances) but Eamon is up.