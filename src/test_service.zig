const dbus = @import("sphdbus");

pub const Request = union(enum) {
    @"/dev/sphaerophoria/TestService": union(enum) {
        @"dev.sphaerophoria.TestService": union(enum) {
            method: union(enum) {
                @"Hello": struct {
                    @"Name": dbus.DbusString,
                },
                @"Goodbye": struct {
                    @"Name": dbus.DbusString,
                },
            },
            get_property: Property,
            set_property: Property,

            const Property = union(enum) {
            };

            pub const docstring: []const u8 =
                \\<interface name="dev.sphaerophoria.TestService">
                \\    <method name="Hello" >
                \\      <arg direction="in" type="s" name="Name" />
                \\      <arg direction="out" type="s" name="value" />
                \\    </method>
                \\    <method name="Goodbye" >
                \\      <arg direction="in" type="s" name="Name" />
                \\      <arg direction="out" type="s" name="value" />
                \\    </method>
                \\  </interface>
           ;
        }
    },
};
