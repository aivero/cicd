//@val external _get: string => string = "Deno.env.get"
@val @return(nullable) external get: string => option<string> = "Deno.env.get";