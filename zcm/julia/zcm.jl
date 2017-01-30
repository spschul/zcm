module ZCM


# C ptr types
module Native

type Zcm
end

#type RecvBuf
#end

type Sub
end

#type Eventlog
#end
#
#type EventlogEvent
#end

end


# TODO: Just testing an example, this is an example of how you can wrap the user's function ptr
#       in a way that will be passable to cfunction()
function qsort!_compare{T}(a_::Ptr{T}, b_::Ptr{T}, lessthan_::Ptr{Void})
    a = unsafe_load(a_)
    b = unsafe_load(b_)
    lessthan = unsafe_pointer_to_objref(lessthan_)::Function;
    ret::Cint = lessthan(a, b) ? -1 : +1;
	return ret;
end

function qsort!{T}(A::Vector{T}, lessthan::Function = <)
    compare_c = cfunction(qsort!_compare, Cint, (Ptr{T}, Ptr{T}, Ptr{Void}))
    ccall(("qsort_r", "libc"), Void, (Ptr{T}, Csize_t, Csize_t, Ptr{Void}, Any),
          A, length(A), sizeof(T), compare_c, lessthan)
    return A
end



# Exported Objects and Methods
type RecvBuf
    recv_utime::Int64;
    zcm       ::Ptr{Native.Zcm};
    data      ::Cstring;
    data_size ::UInt32;
end
export RecvBuf;

type Zcm
    zcm::Ptr{Native.Zcm};

    errno       ::Function; # () ::Int32
    strerror    ::Function; # () ::String

    # TODO refine these comments
    subscribeRaw::Function; #  (channel::String, handler::Handler, usr::Any) ::Ptr{Native.Sub}
    subscribe   ::Function; #  (channel::String, handler::Handler, usr::Any) ::Ptr{Native.Sub}
    unsubscribe ::Function; #  (sub::Ptr{Native.Sub}) ::Int32
    publishRaw  ::Function; #  (channel::String, data::Array{Uint8}, datalen::Uint32) ::Int32
    publish     ::Function; #  (channel::String, msg::Msg) ::Int32
    flush       ::Function; #  () ::Void

    run         ::Function; #  () ::Void
    start       ::Function; #  () ::Void
    stop        ::Function; #  () ::Void
    handle      ::Function; #  () ::Void


    # http://docs.julialang.org/en/stable/manual/calling-c-and-fortran-code/
    # http://julialang.org/blog/2013/05/callback


    function Zcm(url::AbstractString)
        println("Creating zcm with url : ", url);
        instance = new();
        instance.zcm = ccall(("zcm_create", "libzcm"), Ptr{Native.Zcm}, (Cstring,), url);

        # user can force cleanup of their instance by calling `finalize(zcm)`
        finalizer(instance, function(zcm::Zcm)
                                if (zcm.zcm != C_NULL)
                                    println("Destroying zcm instance");
                                    ccall(("zcm_destroy", "libzcm"), Void,
                                          (Ptr{Native.Zcm},), zcm.zcm);
                                    zcm.zcm = C_NULL;
                                end
                            end);

        instance.errno = function()
            return ccall(("zcm_errno", "libzcm"), Cint, (Ptr{Native.Zcm},), instance.zcm);
        end

        instance.strerror = function()
            val =  ccall(("zcm_strerror", "libzcm"), Cstring, (Ptr{Native.Zcm},), instance.zcm);
            if (val == C_NULL)
                return "unable to get strerror";
            else
                return unsafe_string(val);
            end
        end

        # TODO: get this into docs:
        # Note to self: handler could be either a function or a functor, so long as it has
        #               handler(rbuf::Ptr{RecvBuf}, channel::String, usr) defined
        instance.subscribeRaw = function(channel::AbstractString, handler, usr)
            # TODO: almost certainly need to wrap handler in a non-closure function and maintain
            #       a reference to that function so the garbage collector doesn't clean it up
            cFuncPtr = cfunction(handler, Void, (Ptr{RecvBuf}, Cstring, Ptr{Void}));
            return ccall(("zcm_subscribe", "libzcm"), Ptr{Native.Sub},
                         (Ptr{Native.Zcm}, Cstring, Ptr{Void}, Any),
                         instance.zcm, channel, cFuncPtr, usr);
        end

        # TODO: get this into docs:
        # Note to self: handler could be either a function or a functor, so long as it has
        #               handler(rbuf::Ptr{RecvBuf}, channel::String, msg::msgtype, usr) defined
        instance.subscribe = function(channel::AbstractString, MsgType::DataType, handler, usr)
            return instance.subscribeRaw(channel,
                                         function (rbuf::Ptr{RecvBuf}, channel::AbstractString, usr)
                                             msg = MsgType();
                                             # TODO: think we can use `unsafe_wrap` in zcmgen code
                                             #       to turn data ptr into an array
                                             msg.decode(rbuf.data, rbuf.data_size);
                                         end, usr);
        end

        instance.unsubscribe = function(sub::Ptr{Native.Sub})
            return ccall(("zcm_unsubscribe", "libzcm"), Cint,
                         (Ptr{Native.Zcm}, Ptr{Native.Sub}), instance.zcm, sub);
        end

        instance.publishRaw = function(channel::AbstractString, data::Array{UInt8}, datalen::UInt32)
            return ccall(("zcm_publish", "libzcm"), Cint,
                         (Ptr{Native.Zcm}, Cstring, Ptr{Void}, UInt32),
                         instance.zcm, channel, data, datalen);
        end

        # TODO: force msg to be derived from our zcm msg basetype
        instance.publish = function(channel::AbstractString, msg)
            return instance.publishRaw(channel, msg.encode(), msg.encodeLen());
        end

        instance.flush = function()
            return ccall(("zcm_flush", "libzcm"), Void, (Ptr{Native.Zcm},), instance.zcm);
        end

        instance.run = function()
            ccall(("zcm_run", "libzcm"), Void, (Ptr{Native.Zcm},), instance.zcm);
        end

        instance.start = function()
            ccall(("zcm_start", "libzcm"), Void, (Ptr{Native.Zcm},), instance.zcm);
        end

        instance.stop = function()
            ccall(("zcm_stop", "libzcm"), Void, (Ptr{Native.Zcm},), instance.zcm);
        end

        instance.handle = function()
            ccall(("zcm_handle", "libzcm"), Void, (Ptr{Native.Zcm},), instance.zcm);
        end

        return instance;
    end
end
export Zcm;

#type Eventlog
#end
#export Eventlog;
#
#type EventlogEvent
#end
#export EventlogEvent;


end

