pragma circom 2.1.8;


template IDCheck(...) {
    // Private age of the user.
    signal input age;
    // TODO: Add more input signals as required for the other tasks.


    // TODO: Check the age.


    // TODO: Check the zkID and use a template.
    component IDHasher = IDHasher();


    // TODO: Check that the user's country is one of the allowed countries in the provided list.

}

// Define signals as public as required.
component main {public [...]} = IDCheck(...);