include(${CMAKE_CURRENT_SOURCE_DIR}/../../max-sdk-base/script/max-pretarget.cmake)

#############################################################
# MAX EXTERNAL
#############################################################

include_directories( 
	"${MAX_SDK_INCLUDES}"
	"${MAX_SDK_MSP_INCLUDES}"
	"${MAX_SDK_JIT_INCLUDES}"
)

file(GLOB PROJECT_SRC
	"*.h"
	"*.c"
	"*.cpp"
	"*.swift"
)
add_definitions(
	-DACCELERATE_NEW_LAPACK
	-DACCELERATE_LAPACK_ILP64
)
add_library( 
	${PROJECT_NAME} 
	MODULE
	${PROJECT_SRC}
)

include(${CMAKE_CURRENT_SOURCE_DIR}/../../max-sdk-base/script/max-posttarget.cmake)
target_link_libraries(${PROJECT_NAME} PRIVATE "-framework Accelerate")
