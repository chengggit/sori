export type EmbeddedProvider = "naver-ko" | "krdict" | "papago" | "custom";

export const embeddedProviders = [
  { value: "naver-ko", label: "Naver" },
  { value: "krdict", label: "KRDict" },
  { value: "papago", label: "Papago" },
] as const;

export function validCustomEmbed(template: string) {
  try {
    const url = new URL(template.replaceAll("{word}", "test"));
    return url.protocol === "https:" && !url.username && !url.password;
  } catch {
    return false;
  }
}

export function embeddedLookupUrl(provider: EmbeddedProvider, word: string, customUrl = "") {
  const query = encodeURIComponent(word.trim());
  if (provider === "custom") {
    return validCustomEmbed(customUrl) ? customUrl.replaceAll("{word}", query) : "";
  }
  if (provider === "naver-ko") {
    return `https://korean.dict.naver.com/koendict/#/search?query=${query}`;
  }
  if (provider === "krdict")
    return `https://krdict.korean.go.kr/m/eng/searchResult?mainSearchWord=${query}`;
  return `https://papago.naver.com/?sl=ko&tl=en&text=${query}`;
}
