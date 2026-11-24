.pragma library

// UI view state can hold a value or a visible error. Never infer success from
// null data: a successful absent lookup and a failed request are distinct.
function valueOrError(reply) {
    if (!reply || typeof reply.ok !== "boolean")
        throw new Error("Invalid bridge response")
    return reply.ok ? reply.data : { error: reply.error }
}
