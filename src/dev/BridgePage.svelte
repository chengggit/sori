<script lang="ts">
  import { onMount } from "svelte";
  import { platform } from "../platform";
  import type { KoreanToken } from "$lib/nlp/tokenization";

  let ping = $state("waiting…");
  let analysis = $state("waiting…");
  let event = $state("waiting…");

  onMount(() => {
    const unsubscribe = platform.onEvent("dev", (payload) => {
      event = JSON.stringify(payload);
    });

    void (async () => {
      try {
        const reply = await platform.invoke<string>("app:ping");
        ping = reply.ok ? String(reply.data) : reply.error;

        const tokens = await platform.invoke<KoreanToken[]>("analyzeText", {
          text: "학교에 갔어요.",
        });
        analysis = tokens.ok
          ? (tokens.data ?? []).map((token) => `${token.form}/${token.tag}`).join(" ")
          : tokens.error;

        await platform.invoke("dev:emit", { message: "bridge ready" });
      } catch (error) {
        ping = error instanceof Error ? error.message : String(error);
      }
    })();

    return unsubscribe;
  });
</script>

<section>
  <h2>Dev bridge</h2>
  <dl>
    <dt>app:ping</dt>
    <dd data-testid="bridge-ping">{ping}</dd>
    <dt>analyzeText</dt>
    <dd data-testid="bridge-analysis">{analysis}</dd>
    <dt>core:event</dt>
    <dd data-testid="bridge-event">{event}</dd>
  </dl>
  <a href="#/">Back to app</a>
</section>
