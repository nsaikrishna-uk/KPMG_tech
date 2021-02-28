//Javascript on nested object, a function that you pass in the object and get back the value. 

 

const function = (obj) => {
    Object.keys(obj).forEach(key => {

    console.log('key: '+ key + ', value: '+obj[key]);

    if (typeof obj[key] === 'object') {
            function(obj[key])
        }
    })
}

function(Example);
