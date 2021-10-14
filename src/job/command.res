let getJobs = (pairs: array<Instance.pair>) =>
	pairs->Array.map((pair) => {
		switch (pair.int.cmds, pair->Detect.getImage)  {
		| (Some(cmds), Ok(image)) => ({
			Ok({cmds, image, needs: switch pair.int.needs { | Some(needs) => needs | None => [] }})
		}: result<Job_t.t, string>)
		| (_, Error(err)) => Error(err)
		| (None, _) => Error("No commands specified")
		}

	})->Task.resolve