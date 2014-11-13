//
//  ObjectPicking.mm
//  aluminum
//
//  Created by Kyle Reese Almryde on 11/4/14.
//  Copyright (c) 2014 Kyle Reese Almryde. All rights reserved.
//

#import <Aluminum/RendererOSX.h>
#import <Aluminum/MeshUtils.hpp>
#import <Aluminum/MeshBuffer.hpp>
#import <Aluminum/MeshData.hpp>
#import <Aluminum/Shapes.hpp>
#import <Aluminum/Program.hpp>
#import <Aluminum/Camera.hpp>
#import <Aluminum/ResourceHandler.h>

using namespace glm;
using namespace aluminum;

class ObjectPicking : public RendererOSX {
public:

    Camera camera;
    Program shader, phong;
    MeshBuffer cubeMB, rayMB, mb[3];
    ResourceHandler rh;
    
    //modelview and projection matrices
    glm::mat4 M, V, P, fView, pModel = mat4(1);  // View*Projection Matrix and Backup matrix

    //box positions
    vec3 box_positions[3]={
        glm::vec3(-1.5, 0.5, 0.0),
        glm::vec3( 0.0, 0.5, 1.0),
        glm::vec3( 1.5, 0.5, 0.0)
    };
    vec3 obj_positions[3]={
        glm::vec3(-1.5,0.0, 0.0),
        glm::vec3( 0.0,0.0, 1.0),
        glm::vec3( 1.5,0.0, 0.0)
    };
    
    mat4 box_model[3] = {
        mat4(1),
        mat4(1),
        mat4(1)
    };
    
    vec3 box_color[3] = {
        vec3(1.,0.,0.),
        vec3(0.,1.,0.),
        vec3(0.,0.,1.)
    };
    
    vec3 lightPos = vec3(0.0,0.0,10.0);
    vec3 specular = vec3(1.0,1.0,1.0);
    vec3 ambient = vec3(0.0,0.0,0.3);


    glm::vec3 objPt, diff;
    glm::vec3 localObjPt, worldObjPt;
    
    int posLoc = 0,
        normalLoc = 1;
    
    //selected box index
    int selected_box=-1;
    int which = 0;
    int select = 0;
    
    float rX = radians(2.0);
    float rY = radians(2.0);
    float winZ=0;
    
    
    virtual void onCreate() {
        rh.loadProgram(shader, "cube", posLoc, -1, -1, -1);
        rh.loadProgram(phong, "phong", posLoc, normalLoc, -1, -1);
        
        MeshData modelMesh[3];
        
        rh.loadObjIntoMesh(modelMesh[0], "dragon.obj", 1.5);
        rh.loadObjIntoMesh(modelMesh[1], "bunny.obj", .5);
        rh.loadObjIntoMesh(modelMesh[2], "venusl.obj", 0.0005);

        cubeMB.init(MeshUtils::makeCube(0.5), posLoc, -1, -1, -1);
        mb[0].init(modelMesh[0], posLoc, normalLoc, -1, -1);
        mb[1].init(modelMesh[1], posLoc, normalLoc, -1, -1);
        mb[2].init(modelMesh[2], posLoc, normalLoc, -1, -1);


        //set the camera position
        camera = Camera(radians(60.0), (float)width / (float)height, 0.01, 100.0).translateZ(-5.f);
        
        // Set a "Flat" view
        fView = camera.view;

        for (int i = 0; i<3; i++){
            box_model[i] = glm::translate(mat4(1), box_positions[i]);
        }

        glViewport(0, 0, width, height);
        
        //enable depth testing
        glEnable(GL_DEPTH_TEST);
        
        cout<<"Initialization successfull"<<endl;
    }
    
    
    virtual void onFrame() {
        handleMouse();
        
        if (camera.isTransformed) {
            printf("Camera is Transformed!\n");
            camera.transform();
        }

        glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);
        
        vec3 color;
        for(int i = 0; i < 3; i++) {
            if (selected_box == i) {
                M = pModel;
                V = fView;
                P = camera.projection;
                color = vec3(0,1,1);
            } else {
                M = box_model[i];
                V = camera.view;
                P = camera.projection;
                color = box_color[i];
            }
            if (which > 0)
                drawPhong(color, i);
            else
                drawCube(color);
        }
    }
    
    void drawCube(vec3 color) {
        shader.bind();
        {
            glUniformMatrix4fv(shader.uniform("MVP"), 1, 0, ptr(P * V * M));
            glUniform3fv(shader.uniform("vColor"),1, ptr(color));
            cubeMB.draw();
        }
        shader.bind();
    }

    void drawPhong(vec3 diffuse, int index) {
        phong.bind();
        {
            glUniformMatrix4fv(phong.uniform("model"), 1, 0, ptr(M));
            glUniformMatrix4fv(phong.uniform("view"), 1, 0, ptr(V));
            glUniformMatrix4fv(phong.uniform("proj"), 1, 0, ptr(P));
            
            glUniform3f(phong.uniform("lightPos"), 0.0, 0.0, 10.0);
            glUniform3fv(phong.uniform("ambient"), 1, ptr(ambient));
            glUniform3fv(phong.uniform("diffuse"), 1, ptr(diffuse));
            glUniform3fv(phong.uniform("specular"), 1, ptr(specular));
            
            mb[index].draw();
            
        }
        phong.unbind();
    }

    
    virtual void onReshape() {
        //set the viewport size
        glViewport (0, 0, (GLsizei) width, (GLsizei) height);
        camera.perspective(radians(60.0), (float)width / (float)height, 0.01, 100.0);
    }
    
    
    bool getSelection() {
        //read pixel depth at mouse click position
        glReadPixels( mouseX, mouseY, 1, 1, GL_DEPTH_COMPONENT, GL_FLOAT, &winZ);
        
        float minDist = 1000;

        for (int i = 0; i<3; i++) {
            //unproject the obtained winx,winy and winz point to get the object space point
            localObjPt = glm::unProject(vec3(mouseX,mouseY,winZ), camera.view*box_model[i], camera.projection, vec4(0,0,width, height));
            //loop through all scene objects and determine the object clicked by looking at the
            //nearest distance to the object
            float dist = glm::distance(vec3(0.), localObjPt);
            
            if( selected_box <0 && dist<1 && dist<minDist) {
                selected_box = i;
                minDist = dist;
            }
            
            if(selected_box!=-1) {
                printf("\tPicked box: %d\tdist: %f\n", selected_box, dist);
                return true;
            } else
                printf("\tMissed box: %d\tdist: %f\n", i, dist);
        }
        return false;
    }
    
    
    virtual void handleMouse() {
        glm::project(vec3(mouseX,mouseY,0), fView, camera.projection, vec4(0,0,width, height));

//        Raw screen coordinates projected onto the view plane
        glm::vec3 screenObjPt_N = glm::unProject(vec3(mouseX,mouseY,0.), fView, camera.projection, vec4(0,0,width, height));
        glm::vec3 screenObjPt_F = glm::unProject(vec3(mouseX,mouseY,1.), fView, camera.projection, vec4(0,0,width, height));
        diff = glm::normalize(screenObjPt_F - screenObjPt_N);
        
//        XXX "World" Coordinates...View matrix/camera space
//        glm::vec3 worldObjPt_N = glm::unProject(vec3(mouseX,mouseY,0.), camera.view, camera.projection, vec4(0,0,width, height));
//        glm::vec3 worldObjPt_F = glm::unProject(vec3(mouseX,mouseY,1.), camera.view, camera.projection, vec4(0,0,width, height));
//        diff = glm::normalize(worldObjPt_F - worldObjPt_N);
        
//        XXX Local coordinates...Model*View, still follows the camera...
//        glm::vec3 localObjPt_N = glm::unProject(vec3(mouseX,mouseY,0.), camera.view*box_model[selected_box], camera.projection, vec4(0,0,width, height));
//        glm::vec3 localObjPt_F = glm::unProject(vec3(mouseX,mouseY,1.), camera.view*box_model[selected_box], camera.projection, vec4(0,0,width, height));
//        diff = glm::normalize(localObjPt_F - localObjPt_N);
        
//        glm::vec3 objPt_N = glm::unProject(vec3(mouseX,mouseY,0.), fView*box_model[selected_box], camera.projection, vec4(0,0,width, height));
//        glm::vec3 objPt_F = glm::unProject(vec3(mouseX,mouseY,1.), fView*box_model[selected_box], camera.projection, vec4(0,0,width, height));
//        diff = glm::normalize(objPt_F - objPt_N);


        if (isMoving && selected_box!= -1) {
            
            printf("We're MOVING!!\n");
            pModel = glm::translate(fView, vec3(diff.x*2.5f, diff.y*2.5f,-3.));
        }
        
        if (isPressing)
        {
            // If we pick an object for the first time
            if (selected_box < 0 && getSelection()) {
                printf("\tSELECTED!!\n");
                // This snaps the object to the location of the mouse
                pModel = glm::translate(fView, vec3(diff.x*2.f, diff.y*2.f,-3.));
    
            // If a cube is selected, and we "pick it" again, deselect the cube and place .. the
            } else if (selected_box != -1 && getSelection()){
                printf("\tDESELECTED!! %d\n",select);
                switch (select) {
                    case 0:
                        box_model[selected_box] = glm::translate(mat4(1), vec3(diff.x*2.5f, diff.y*2.5f,box_positions[selected_box].z));
                        break;
                    case 1:
                        box_model[selected_box] = glm::translate(fView, vec3(diff.x*2.5f, diff.y*2.5f,box_positions[selected_box].z));
                        break;
                    case 2:
                        box_model[selected_box] = glm::translate(fView, vec3(diff.x*2.5f, diff.y*2.5f,box_positions[selected_box].z));
                        break;
                    case 3:
                        box_model[selected_box] = glm::translate(mat4(1), box_positions[selected_box]);
                        break;
                    default:
                        break;
                }
                selected_box = -1;
            }
        }
        
        
        isDragging = false;
        isMoving = false;
        isPressing = false;
        
    }
    
    
    virtual void keyDown(char key) {
        
        switch(key) {
            case kVK_Space :
                camera.resetVectors();
                camera.translateZ(-5.f);
                selected_box = -1;

                if(which < 1) {
                    for (int i = 0; i<3; i++){
                        box_model[i] = glm::translate(mat4(1), box_positions[i]);
                    }
                    
                } else{
                    for (int i = 0; i<3; i++){
                        box_model[i] = glm::translate(mat4(1), obj_positions[i]);
                    }
                    
                }
                break;
            case kVK_ANSI_W :
                camera.translate(vec3(0,0,0.2));
                break;
            case kVK_ANSI_S :
                camera.translate(vec3(0,0,-0.2));
                break;
            case kVK_ANSI_A :
                camera.rotate(vec3(0.0,rY,0.0));
                break;
            case kVK_ANSI_D :
                camera.rotate(vec3(0.0,-rY,0.0));
                break;
            case kVK_ANSI_Q :
                camera.rotate(vec3(rX,0.0,0.0));
                break;
            case kVK_ANSI_E :
                camera.rotate(vec3(-rX,0.0,0.0));
                break;
            case kVK_UpArrow:
                camera.printCameraInfo();
                if(which < 1) {
                    which++;
                    for (int i = 0; i<3; i++){
                        box_model[i] = glm::translate(mat4(1), obj_positions[i]);
                    }

                } else{
                    which--;
                    for (int i = 0; i<3; i++){
                        box_model[i] = glm::translate(mat4(1), box_positions[i]);
                    }

                }
                break;
            case kVK_DownArrow:
                camera.printCameraInfo();
                select < 3? select++: select = 0;
                break;

        }
    }
   
};

int main() {
    return ObjectPicking().start("aluminum::ObjectPicking", 100, 100, 400, 400);
}