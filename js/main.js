var delete_uri = 'https://vns.ariesme.com/api/delete';

$(document).ready(() => {
    $(document).on('click', '#delete', (e) => {
        // Delete server dialog
        $('#serverName').attr('placeholder', $(e.target).attr('sn'));
        $('#deleteServerModal').modal('show');
    });

    $(document).on('click', '#confirm', (e) => {
        // Server name
        var name = $('#serverName').attr('placeholder');
        // API token
        var token = $('#password').val();

        // Delete server request
        $.post(delete_uri, { "name": name, "token": token }, (e) => {
            if (e == 1) {
                $('#message').html("[" + name + "] deleted successful! Web page will reload!");
                $('#message').removeClass('alert-danger').addClass('alert-success');
                $('#message').slideDown(500);
                setTimeout(() => {
                    location.reload(true);
                }, 3000);
            } else if (e == 0) {
                $('#message').html("[" + name + "] is not existed!");
                $('#message').slideDown(500);
                setTimeout(() => {
                    $('#message').slideUp(500);
                }, 3000);
            } else if (e == -1) {
                $('#message').html("Please enter correct password!");
                $('#message').slideDown(500);
                setTimeout(() => {
                    $('#message').slideUp(500);
                }, 3000);
            }
        });
    });
});