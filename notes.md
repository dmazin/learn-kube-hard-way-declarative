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


### 9 Jan 2023
The [TF module for VMs](https://github.com/terraform-google-modules/terraform-google-vm/tree/master/modules/compute_instance) seems to force you to create a template, and only from that template you can create VMs. That is just fine with me. It forces a little DRYness. This is not really a challenge. The challenge is converting the command-line arguments to the declarative form (I mean, that is the point of this entire project, but I am now running into a bit where I'm not super clear what to do next.) Here is how Hightower creates the control plane VMs.

- [ ] Oh wait, one TODO before I forget: when [creating the kubernetes-the-hard-way-allow-internal firewall rule](https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/03-compute-resources.md#firewall-rules), Hightower adds `10.200.0.0/16` to the source range which I did not. This is the range for the pods themselves; for some reason he does not actually create a subnet. I am not adding this yet, but I do wonder if maybe I should just create a subnet for tidiness.

Anyway, back to the VMs. Here is how Hightower creates them.
```bash
for i in 0 1 2; do
  gcloud compute instances create controller-${i} \
    --async \
    --boot-disk-size 200GB \
    --can-ip-forward \
    --image-family ubuntu-2004-lts \
    --image-project ubuntu-os-cloud \
    --machine-type e2-standard-2 \
    --private-network-ip 10.240.0.1${i} \
    --scopes compute-rw,storage-ro,service-management,service-control,logging-write,monitoring \
    --subnet kubernetes \
    --tags kubernetes-the-hard-way,controller
done
```

These are the flags I don't understand.
- can-ip-forward
- scopes

The scopes trip me up because I am not sure at all what they are. How do they relate to service account roles? What are these? `--help` is unclear. What about the docs? OK, here's what the docs have to say.
> Access scopes are the legacy method of specifying authorization for your instance.

OK.

> IAM restricts access to APIs based on the IAM roles that are granted to the service account.
> Access scopes potentially further limit access to API methods.

And...

> The best practice is to set the full cloud-platform access scope on the instance, then control the service account's access using IAM roles.

OK, so I understand scopes now. Scopes apply to VMs. They relate to OAuth, which is why they're called scopes. They control the requests made by the gcloud CLI and client libs running on the VM. But they do not affect gRPCs (I guess because they are legacy). The way they relate to IAM roles is that they are the older form of authorization.

A decision: should I just use scopes, and come back to it later, or should I improve? I want to improve. That way if someone actually reads my work, they are learning best practices. I just have to figure out what roles the scopes map to.

The scopes: `compute-rw,storage-ro,service-management,service-control,logging-write,monitoring`

Man, the documentation for these is non-existent. Does `compute-rw` mean that the instance is able to create/edit compute resources? That's a little surprising. I don't think we'd want that. Here is the crux: because I don't know the goal of the scopes, and because there is no documented scope-to-role mapping, I don't know what roles to use.

But I can kind of bluster my way through this. The intent of logging-write,monitoring is clear enough, and I'll figure out what roles it maps to. For the other scopes, I simply will pass over them, and if I am unable to do something in the future due to a permissions issue, I'll be able to add the new permission thanks to the error message.

For monitoring, I think the important thing is that the compute instances need to be able to write metrics, so I'll grant [roles/monitoring.metricWriter](https://cloud.google.com/iam/docs/understanding-roles#monitoring.metricWriter). For logging, I'll grant [roles/logging.logWriter](https://cloud.google.com/iam/docs/understanding-roles#logging.logWriter).

Oh, by the way, I can tell what role the storage-ro access scope might map to, but I do not understand why the instances might need it. So I'll leave it for now. Also, I am sure that the instances will need some compute roles – we'll see. And, finally, I did figure out that the service-management and service-control scopes map to [these roles](https://cloud.google.com/service-infrastructure/docs/service-management/access-control).

Of course, the other thing I need to do is create the service accounts used by the VMs.

A TODO:
- [ ] Rename the project var to project_id. This is the real name of the thing I'm referring to: it's the ID. It's unique across GCP.

OK, I am failing to create the service accounts and assign the roles to it. I think that is probably because my service account is an editor, not an owner. I will make it an owner.