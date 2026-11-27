export interface Response<T> {
  ok: boolean;
  data: T | null;
  error: string;
}

export function unwrapData<T>(response: Response<T>): T {
  if (!response.ok) throw new Error(response.error || "Unknown error");
  if (response.data === null) throw new Error("No data returned");
  return response.data;
}
