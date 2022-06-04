let one = ["one","two"]
let two = ["one","two"]

let jobs = [one, two]

let theSame = jobs->Array.map((needs) => needs == one)
    ->Array.reduce((acc, theSame) => {
        acc && theSame
    }, true)

switch theSame {
| true => Console.log("Yooo")
| _ => ()
}
